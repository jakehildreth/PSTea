BeforeAll {
    . $PSScriptRoot/../Private/Core/Copy-ElmModel.ps1
}

Describe 'Copy-ElmModel' -Tag 'Unit', 'P1' {
    Context 'When given a flat PSCustomObject' {
        BeforeAll {
            $original = [PSCustomObject]@{ Name = 'Alice'; Count = 42 }
            $copy = Copy-ElmModel -Model $original
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
            $copy = Copy-ElmModel -Model $original
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
            $copy = Copy-ElmModel -Model $original
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
            { Copy-ElmModel -Model $null } | Should -Throw
        }
    }

    Context 'When given a hashtable' {
        BeforeAll {
            $original = @{ Key = 'val'; Num = 7 }
            $copy = Copy-ElmModel -Model $original
        }

        It 'Should return an object with equivalent property values' {
            $copy.Key | Should -Be $original.Key
            $copy.Num | Should -Be $original.Num
        }
    }
}
