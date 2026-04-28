BeforeAll {
    . $PSScriptRoot/../Private/Core/Copy-TeaModel.ps1
}

Describe 'Copy-TeaModel' -Tag 'Unit', 'P1' {
    Context 'When given a flat PSCustomObject' {
        BeforeAll {
            $original = [PSCustomObject]@{ Name = 'Alice'; Count = 42 }
            $copy = Copy-TeaModel -Model $original
        }

        It 'Should return an object with equal property values' {
            $copy.Name  | Should -Be $original.Name
            $copy.Count | Should -Be $original.Count
        }

        It 'Should return a distinct reference (not the same object)' {
            [object]::ReferenceEquals($copy, $original) | Should -BeFalse
        }
    }

    Context 'When given a nested PSCustomObject' {
        BeforeAll {
            $original = [PSCustomObject]@{
                Outer = [PSCustomObject]@{ Inner = 'value' }
            }
            $copy = Copy-TeaModel -Model $original
        }

        It 'Should have equal nested property values' {
            $copy.Outer.Inner | Should -Be $original.Outer.Inner
        }

        It 'Should return a distinct reference for nested objects' {
            [object]::ReferenceEquals($copy.Outer, $original.Outer) | Should -BeFalse
        }
    }

    Context 'When the model has an array property' {
        BeforeAll {
            $original = [PSCustomObject]@{ Items = @('a', 'b', 'c') }
            $copy = Copy-TeaModel -Model $original
        }

        It 'Should copy the array values' {
            $copy.Items | Should -Be $original.Items
        }

        It 'Should return an independent array (mutating copy does not affect original)' {
            $copy.Items = @('x', 'y')
            $original.Items | Should -Be @('a', 'b', 'c')
        }
    }

    Context 'When given $null' {
        It 'Should throw a terminating error' {
            { Copy-TeaModel -Model $null } | Should -Throw
        }
    }

    Context 'When given a hashtable' {
        BeforeAll {
            $original = @{ Key = 'val'; Num = 7 }
            $copy = Copy-TeaModel -Model $original
        }

        It 'Should return an object with equivalent property values' {
            $copy.Key | Should -Be $original.Key
            $copy.Num | Should -Be $original.Num
        }
    }

    Context 'When the model has an array of PSCustomObjects with string properties' {
        # Regression: Copy-TeaModel must preserve string types on nested PSCustomObject
        # items inside arrays. Callers must not need to cast [string] to call .Substring etc.
        It 'Should preserve string type on Name property of each item' {
            $original = [PSCustomObject]@{
                Rows = @(
                    [PSCustomObject]@{ Name = 'alpha'; Value = 1 }
                    [PSCustomObject]@{ Name = 'beta';  Value = 2 }
                )
            }
            $copy = Copy-TeaModel -Model $original
            $copy.Rows[0].Name | Should -BeOfType [string]
            $copy.Rows[1].Name | Should -BeOfType [string]
        }

        It 'Should preserve string value on Name property of each item' {
            $original = [PSCustomObject]@{
                Rows = @(
                    [PSCustomObject]@{ Name = 'alpha'; Value = 1 }
                    [PSCustomObject]@{ Name = 'beta';  Value = 2 }
                )
            }
            $copy = Copy-TeaModel -Model $original
            $copy.Rows[0].Name | Should -Be 'alpha'
            $copy.Rows[1].Name | Should -Be 'beta'
        }

        It 'Should allow calling string methods on copied Name without explicit cast' {
            $original = [PSCustomObject]@{
                Rows = @(
                    [PSCustomObject]@{ Name = 'hello-world'; Value = 0 }
                )
            }
            $copy = Copy-TeaModel -Model $original
            { $copy.Rows[0].Name.Substring(0, 5) } | Should -Not -Throw
            $copy.Rows[0].Name.Substring(0, 5) | Should -Be 'hello'
        }

        It 'Should deep-clone each item in the array independently' {
            $item     = [PSCustomObject]@{ Name = 'original'; Value = 99 }
            $original = [PSCustomObject]@{ Rows = @($item) }
            $copy     = Copy-TeaModel -Model $original
            [object]::ReferenceEquals($copy.Rows[0], $item) | Should -BeFalse
        }

        It 'Should preserve numeric types on PSCustomObject items in arrays' {
            $original = [PSCustomObject]@{
                Rows = @(
                    [PSCustomObject]@{ Name = 'proc'; CpuSec = 3.14; MemMB = 128.5; Threads = 4 }
                )
            }
            $copy = Copy-TeaModel -Model $original
            $copy.Rows[0].CpuSec  | Should -Be 3.14
            $copy.Rows[0].MemMB   | Should -Be 128.5
            $copy.Rows[0].Threads | Should -Be 4
        }
    }
}
