BeforeAll {
    . $PSScriptRoot/../Public/Style/New-ElmStyle.ps1
}

Describe 'New-ElmStyle' -Tag 'Unit', 'P2' {
    Context 'When called with no parameters' {
        It 'Should return a PSCustomObject' {
            New-ElmStyle | Should -BeOfType [PSCustomObject]
        }

        It 'Should have Bold = $false' {
            (New-ElmStyle).Bold | Should -BeFalse
        }

        It 'Should have Italic = $false' {
            (New-ElmStyle).Italic | Should -BeFalse
        }

        It 'Should have Underline = $false' {
            (New-ElmStyle).Underline | Should -BeFalse
        }

        It 'Should have Strikethrough = $false' {
            (New-ElmStyle).Strikethrough | Should -BeFalse
        }

        It 'Should have Border = None' {
            (New-ElmStyle).Border | Should -Be 'None'
        }

        It 'Should have Align = Left' {
            (New-ElmStyle).Align | Should -Be 'Left'
        }

        It 'Should have all padding fields = 0' {
            $result = New-ElmStyle
            $result.PaddingTop    | Should -Be 0
            $result.PaddingRight  | Should -Be 0
            $result.PaddingBottom | Should -Be 0
            $result.PaddingLeft   | Should -Be 0
        }

        It 'Should have all margin fields = 0' {
            $result = New-ElmStyle
            $result.MarginTop    | Should -Be 0
            $result.MarginRight  | Should -Be 0
            $result.MarginBottom | Should -Be 0
            $result.MarginLeft   | Should -Be 0
        }

        It 'Should have Foreground = $null' {
            (New-ElmStyle).Foreground | Should -BeNullOrEmpty
        }

        It 'Should have Background = $null' {
            (New-ElmStyle).Background | Should -BeNullOrEmpty
        }

        It 'Should have Width = $null' {
            (New-ElmStyle).Width | Should -BeNullOrEmpty
        }

        It 'Should have Height = $null' {
            (New-ElmStyle).Height | Should -BeNullOrEmpty
        }
    }

    Context 'When -Padding 2 is specified' {
        It 'Should set all four padding fields to 2' {
            $result = New-ElmStyle -Padding 2
            $result.PaddingTop    | Should -Be 2
            $result.PaddingRight  | Should -Be 2
            $result.PaddingBottom | Should -Be 2
            $result.PaddingLeft   | Should -Be 2
        }
    }

    Context 'When -Padding 1, 2 is specified' {
        It 'Should set top/bottom = 1 and left/right = 2' {
            $result = New-ElmStyle -Padding 1, 2
            $result.PaddingTop    | Should -Be 1
            $result.PaddingBottom | Should -Be 1
            $result.PaddingRight  | Should -Be 2
            $result.PaddingLeft   | Should -Be 2
        }
    }

    Context 'When -Padding 1, 2, 3, 4 is specified' {
        It 'Should set padding in CSS order (top, right, bottom, left)' {
            $result = New-ElmStyle -Padding 1, 2, 3, 4
            $result.PaddingTop    | Should -Be 1
            $result.PaddingRight  | Should -Be 2
            $result.PaddingBottom | Should -Be 3
            $result.PaddingLeft   | Should -Be 4
        }
    }

    Context 'When -Margin 1 is specified' {
        It 'Should set all four margin fields to 1' {
            $result = New-ElmStyle -Margin 1
            $result.MarginTop    | Should -Be 1
            $result.MarginRight  | Should -Be 1
            $result.MarginBottom | Should -Be 1
            $result.MarginLeft   | Should -Be 1
        }
    }

    Context 'When -Margin 1, 2 is specified' {
        It 'Should set top/bottom = 1 and left/right = 2' {
            $result = New-ElmStyle -Margin 1, 2
            $result.MarginTop    | Should -Be 1
            $result.MarginBottom | Should -Be 1
            $result.MarginRight  | Should -Be 2
            $result.MarginLeft   | Should -Be 2
        }
    }

    Context 'When -Base is specified' {
        It 'Should inherit Bold from base' {
            $base = New-ElmStyle -Bold
            $result = New-ElmStyle -Base $base
            $result.Bold | Should -BeTrue
        }

        It 'Should replace overridden Foreground field' {
            $base = New-ElmStyle -Foreground '#FF0000'
            $result = New-ElmStyle -Base $base -Foreground '#00FF00'
            $result.Foreground | Should -Be '#00FF00'
        }

        It 'Should preserve non-overridden base fields when overriding another' {
            $base = New-ElmStyle -Bold -Border 'Rounded'
            $result = New-ElmStyle -Base $base -Foreground '#FF0000'
            $result.Bold   | Should -BeTrue
            $result.Border | Should -Be 'Rounded'
        }
    }
}
