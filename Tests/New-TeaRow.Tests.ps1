BeforeAll {
    . $PSScriptRoot/../Public/View/New-TeaRow.ps1
}

Describe 'New-TeaRow' {
    Context 'When called with children' {
        It 'Should return a PSCustomObject' {
            $result = New-TeaRow -Children @()
            $result | Should -BeOfType [PSCustomObject]
        }

        It 'Should have Type = Box' {
            $result = New-TeaRow -Children @()
            $result.Type | Should -Be 'Box'
        }

        It 'Should have Direction = Horizontal' {
            $result = New-TeaRow -Children @()
            $result.Direction | Should -Be 'Horizontal'
        }

        It 'Should store the children array' {
            . $PSScriptRoot/../Public/View/New-TeaText.ps1
            $child = New-TeaText -Content 'hi'
            $result = New-TeaRow -Children @($child)
            $result.Children.Count | Should -Be 1
        }

        It 'Should default Style to $null' {
            $result = New-TeaRow -Children @()
            $result.Style | Should -BeNullOrEmpty
        }

        It 'Should default Width to Auto' {
            $result = New-TeaRow -Children @()
            $result.Width | Should -Be 'Auto'
        }

        It 'Should default Height to Auto' {
            $result = New-TeaRow -Children @()
            $result.Height | Should -Be 'Auto'
        }
    }

    Context 'When -Width and -Height are provided' {
        It 'Should store the explicit Width' {
            $result = New-TeaRow -Children @() -Width 'Fill'
            $result.Width | Should -Be 'Fill'
        }

        It 'Should store a percentage Width string' {
            $result = New-TeaRow -Children @() -Width '50%'
            $result.Width | Should -Be '50%'
        }

        It 'Should store an explicit Height' {
            $result = New-TeaRow -Children @() -Height 'Fill'
            $result.Height | Should -Be 'Fill'
        }
    }

    Context 'When -Children is null' {
        It 'Should throw a terminating error' {
            { New-TeaRow -Children $null } | Should -Throw
        }
    }
}
