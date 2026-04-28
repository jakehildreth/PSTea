BeforeAll {
    . $PSScriptRoot/../Public/View/New-TeaBox.ps1
}

Describe 'New-TeaBox' {
    Context 'When called with children' {
        It 'Should return a PSCustomObject' {
            $result = New-TeaBox -Children @()
            $result | Should -BeOfType [PSCustomObject]
        }

        It 'Should have Type = Box' {
            $result = New-TeaBox -Children @()
            $result.Type | Should -Be 'Box'
        }

        It 'Should have Direction = Vertical' {
            $result = New-TeaBox -Children @()
            $result.Direction | Should -Be 'Vertical'
        }

        It 'Should store the children array' {
            . $PSScriptRoot/../Public/View/New-TeaText.ps1
            $child = New-TeaText -Content 'hi'
            $result = New-TeaBox -Children @($child)
            $result.Children.Count | Should -Be 1
        }

        It 'Should default Style to $null' {
            $result = New-TeaBox -Children @()
            $result.Style | Should -BeNullOrEmpty
        }

        It 'Should default Width to Auto' {
            $result = New-TeaBox -Children @()
            $result.Width | Should -Be 'Auto'
        }

        It 'Should default Height to Auto' {
            $result = New-TeaBox -Children @()
            $result.Height | Should -Be 'Auto'
        }
    }

    Context 'When -Width and -Height are provided' {
        It 'Should store the explicit Width' {
            $result = New-TeaBox -Children @() -Width 'Fill'
            $result.Width | Should -Be 'Fill'
        }

        It 'Should store an integer Width' {
            $result = New-TeaBox -Children @() -Width 40
            $result.Width | Should -Be 40
        }

        It 'Should store an explicit Height' {
            $result = New-TeaBox -Children @() -Height 10
            $result.Height | Should -Be 10
        }
    }

    Context 'When -Children is null' {
        It 'Should throw a terminating error' {
            { New-TeaBox -Children $null } | Should -Throw
        }
    }
}
