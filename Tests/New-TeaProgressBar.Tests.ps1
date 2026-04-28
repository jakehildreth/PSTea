BeforeAll {
    . $PSScriptRoot/../Public/View/New-TeaProgressBar.ps1
}

Describe 'New-TeaProgressBar' -Tag 'Unit', 'P9' {

    Context 'Return value structure' {
        It 'Should return a Text node' {
            $bar = New-TeaProgressBar -Value 0.5
            $bar.Type | Should -Be 'Text'
        }

        It 'Should have a non-empty Content property' {
            $bar = New-TeaProgressBar -Value 0.5
            $bar.Content | Should -Not -BeNullOrEmpty
        }

        It 'Should have Width Auto' {
            $bar = New-TeaProgressBar -Value 0.5
            $bar.Width | Should -Be 'Auto'
        }

        It 'Should have Height Auto' {
            $bar = New-TeaProgressBar -Value 0.5
            $bar.Height | Should -Be 'Auto'
        }
    }

    Context 'Bar content format' {
        It 'Should start with [ and end with ]' {
            $bar = New-TeaProgressBar -Value 0.5 -Width 20
            $bar.Content[0]                    | Should -Be '['
            $bar.Content[$bar.Content.Length - 1] | Should -Be ']'
        }

        It 'Should have total length equal to Width' {
            $bar = New-TeaProgressBar -Value 0.5 -Width 20
            $bar.Content.Length | Should -Be 20
        }

        It 'Should be all filled at Value 1.0' {
            $bar = New-TeaProgressBar -Value 1.0 -Width 12
            # inner = 10 chars, all '#'
            $bar.Content | Should -Be ('[' + ('#' * 10) + ']')
        }

        It 'Should be all empty at Value 0.0' {
            $bar = New-TeaProgressBar -Value 0.0 -Width 12
            $bar.Content | Should -Be ('[' + ('-' * 10) + ']')
        }

        It 'Should fill approximately half at Value 0.5' {
            $bar = New-TeaProgressBar -Value 0.5 -Width 22
            # inner = 20, filled = 10, empty = 10
            $bar.Content | Should -Be ('[' + ('#' * 10) + ('-' * 10) + ']')
        }
    }

    Context 'Percent parameter set' {
        It 'Should accept -Percent 100 and fill bar completely' {
            $bar = New-TeaProgressBar -Percent 100 -Width 12
            $bar.Content | Should -Be ('[' + ('#' * 10) + ']')
        }

        It 'Should accept -Percent 0 and show empty bar' {
            $bar = New-TeaProgressBar -Percent 0 -Width 12
            $bar.Content | Should -Be ('[' + ('-' * 10) + ']')
        }

        It 'Should accept -Percent 50' {
            $bar = New-TeaProgressBar -Percent 50 -Width 22
            $bar.Content | Should -Be ('[' + ('#' * 10) + ('-' * 10) + ']')
        }
    }

    Context 'Value clamping' {
        It 'Should clamp Value above 1.0 to full bar' {
            $bar = New-TeaProgressBar -Value 2.5 -Width 12
            $bar.Content | Should -Be ('[' + ('#' * 10) + ']')
        }

        It 'Should clamp Value below 0.0 to empty bar' {
            $bar = New-TeaProgressBar -Value -0.5 -Width 12
            $bar.Content | Should -Be ('[' + ('-' * 10) + ']')
        }
    }

    Context 'Custom characters' {
        It 'Should use custom FilledChar' {
            $bar = New-TeaProgressBar -Value 1.0 -Width 7 -FilledChar '='
            $bar.Content | Should -Be ('[' + ('=' * 5) + ']')
        }

        It 'Should use custom EmptyChar' {
            $bar = New-TeaProgressBar -Value 0.0 -Width 7 -EmptyChar '.' 
            $bar.Content | Should -Be ('[' + ('.' * 5) + ']')
        }
    }

    Context 'Style passthrough' {
        It 'Should pass Style to the Text node' {
            $style = [PSCustomObject]@{ Foreground = 'Green' }
            $bar   = New-TeaProgressBar -Value 0.5 -Style $style
            $bar.Style | Should -Be $style
        }

        It 'Should have null Style when omitted' {
            $bar = New-TeaProgressBar -Value 0.5
            $bar.Style | Should -BeNullOrEmpty
        }
    }

    Context 'Error handling' {
        It 'Should throw when Width is below minimum (4)' {
            { New-TeaProgressBar -Value 0.5 -Width 3 } | Should -Throw
        }
    }
}
