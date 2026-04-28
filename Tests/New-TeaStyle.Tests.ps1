BeforeAll {
    . $PSScriptRoot/../Public/Style/New-TeaStyle.ps1
}

Describe 'New-TeaStyle' -Tag 'Unit', 'P2' {
    Context 'When called with no parameters' {
        It 'Should return a PSCustomObject' {
            New-TeaStyle | Should -BeOfType [PSCustomObject]
        }

        It 'Should have Bold = $false' {
            (New-TeaStyle).Bold | Should -BeFalse
        }

        It 'Should have Italic = $false' {
            (New-TeaStyle).Italic | Should -BeFalse
        }

        It 'Should have Underline = $false' {
            (New-TeaStyle).Underline | Should -BeFalse
        }

        It 'Should have Strikethrough = $false' {
            (New-TeaStyle).Strikethrough | Should -BeFalse
        }

        It 'Should have Border = None' {
            (New-TeaStyle).Border | Should -Be 'None'
        }

        It 'Should have Align = Left' {
            (New-TeaStyle).Align | Should -Be 'Left'
        }

        It 'Should have all padding fields = 0' {
            $result = New-TeaStyle
            $result.PaddingTop    | Should -Be 0
            $result.PaddingRight  | Should -Be 0
            $result.PaddingBottom | Should -Be 0
            $result.PaddingLeft   | Should -Be 0
        }

        It 'Should have all margin fields = 0' {
            $result = New-TeaStyle
            $result.MarginTop    | Should -Be 0
            $result.MarginRight  | Should -Be 0
            $result.MarginBottom | Should -Be 0
            $result.MarginLeft   | Should -Be 0
        }

        It 'Should have Foreground = $null' {
            (New-TeaStyle).Foreground | Should -BeNullOrEmpty
        }

        It 'Should have Background = $null' {
            (New-TeaStyle).Background | Should -BeNullOrEmpty
        }

        It 'Should have Width = $null' {
            (New-TeaStyle).Width | Should -BeNullOrEmpty
        }

        It 'Should have Height = $null' {
            (New-TeaStyle).Height | Should -BeNullOrEmpty
        }
    }

    Context 'When -Padding 2 is specified' {
        It 'Should set all four padding fields to 2' {
            $result = New-TeaStyle -Padding 2
            $result.PaddingTop    | Should -Be 2
            $result.PaddingRight  | Should -Be 2
            $result.PaddingBottom | Should -Be 2
            $result.PaddingLeft   | Should -Be 2
        }
    }

    Context 'When -Padding 1, 2 is specified' {
        It 'Should set top/bottom = 1 and left/right = 2' {
            $result = New-TeaStyle -Padding 1, 2
            $result.PaddingTop    | Should -Be 1
            $result.PaddingBottom | Should -Be 1
            $result.PaddingRight  | Should -Be 2
            $result.PaddingLeft   | Should -Be 2
        }
    }

    Context 'When -Padding 1, 2, 3, 4 is specified' {
        It 'Should set padding in CSS order (top, right, bottom, left)' {
            $result = New-TeaStyle -Padding 1, 2, 3, 4
            $result.PaddingTop    | Should -Be 1
            $result.PaddingRight  | Should -Be 2
            $result.PaddingBottom | Should -Be 3
            $result.PaddingLeft   | Should -Be 4
        }
    }

    Context 'When -Margin 1 is specified' {
        It 'Should set all four margin fields to 1' {
            $result = New-TeaStyle -Margin 1
            $result.MarginTop    | Should -Be 1
            $result.MarginRight  | Should -Be 1
            $result.MarginBottom | Should -Be 1
            $result.MarginLeft   | Should -Be 1
        }
    }

    Context 'When -Margin 1, 2 is specified' {
        It 'Should set top/bottom = 1 and left/right = 2' {
            $result = New-TeaStyle -Margin 1, 2
            $result.MarginTop    | Should -Be 1
            $result.MarginBottom | Should -Be 1
            $result.MarginRight  | Should -Be 2
            $result.MarginLeft   | Should -Be 2
        }
    }

    Context 'When -Base is specified' {
        It 'Should inherit Bold from base' {
            $base = New-TeaStyle -Bold
            $result = New-TeaStyle -Base $base
            $result.Bold | Should -BeTrue
        }

        It 'Should replace overridden Foreground field' {
            $base = New-TeaStyle -Foreground '#FF0000'
            $result = New-TeaStyle -Base $base -Foreground '#00FF00'
            $result.Foreground | Should -Be '#00FF00'
        }

        It 'Should preserve non-overridden base fields when overriding another' {
            $base = New-TeaStyle -Bold -Border 'Rounded'
            $result = New-TeaStyle -Base $base -Foreground '#FF0000'
            $result.Bold   | Should -BeTrue
            $result.Border | Should -Be 'Rounded'
        }
    }
}
