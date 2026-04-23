BeforeAll {
    . $PSScriptRoot/../Private/Style/Resolve-ElmColor.ps1
    . $PSScriptRoot/../Private/Style/ConvertTo-BorderChars.ps1
    . $PSScriptRoot/../Public/Style/New-ElmStyle.ps1
    . $PSScriptRoot/../Private/Style/Apply-ElmStyle.ps1
    $esc = [char]27
}

Describe 'Apply-ElmStyle' -Tag 'Unit', 'P2' {
    Context 'When style is $null' {
        It 'Should return content unchanged' {
            $result = Apply-ElmStyle -Content 'hello' -Width 5 -Style $null
            $result | Should -Be 'hello'
        }
    }

    Context 'When style has Bold = $true' {
        It 'Should wrap content with bold SGR sequences' {
            $style = New-ElmStyle -Bold
            $result = Apply-ElmStyle -Content 'hello' -Width 5 -Style $style
            $result | Should -Be "$($esc)[1mhello$($esc)[0m"
        }
    }

    Context 'When style has PaddingLeft = 2' {
        It 'Should prepend two spaces to content' {
            $style = New-ElmStyle -Padding 0, 0, 0, 2
            $result = Apply-ElmStyle -Content 'hello' -Width 5 -Style $style
            $result | Should -Be '  hello'
        }
    }

    Context 'When style has PaddingTop = 1' {
        It 'Should add a blank line above content' {
            $style = New-ElmStyle -Padding 1, 0, 0, 0
            $result = Apply-ElmStyle -Content 'hello' -Width 5 -Style $style
            $lines = $result -split "`n"
            $lines.Count | Should -Be 2
            $lines[0] | Should -Be '     '
            $lines[1] | Should -Be 'hello'
        }
    }

    Context 'When style has Border = Rounded' {
        It 'Should wrap content with rounded border chars' {
            $style = New-ElmStyle -Border 'Rounded'
            $result = Apply-ElmStyle -Content 'hello' -Width 5 -Style $style
            $lines = $result -split "`n"
            $lines[0] | Should -Be '╭─────╮'
            $lines[1] | Should -Be '│hello│'
            $lines[2] | Should -Be '╰─────╯'
        }
    }

    Context 'When style has Border = Normal' {
        It 'Should produce three output lines' {
            $style = New-ElmStyle -Border 'Normal'
            $result = Apply-ElmStyle -Content 'hi' -Width 2 -Style $style
            $lines = $result -split "`n"
            $lines.Count | Should -Be 3
        }

        It 'Should draw correct top border' {
            $style = New-ElmStyle -Border 'Normal'
            $lines = (Apply-ElmStyle -Content 'hi' -Width 2 -Style $style) -split "`n"
            $lines[0] | Should -Be '┌──┐'
        }
    }

    Context 'When style has Bold, PaddingLeft=1, PaddingRight=1, and Border=Normal' {
        It 'Should apply SGR then padding then border' {
            $style = New-ElmStyle -Bold -Padding 0, 1, 0, 1 -Border 'Normal'
            $result = Apply-ElmStyle -Content 'hi' -Width 2 -Style $style
            $lines = $result -split "`n"
            $lines[0] | Should -Be '┌────┐'
            $lines[1] | Should -Be "│ $($esc)[1mhi$($esc)[0m │"
            $lines[2] | Should -Be '└────┘'
        }
    }

    Context 'When style has MarginTop = 1' {
        It 'Should prepend a blank line' {
            $style = New-ElmStyle -Margin 1, 0, 0, 0
            $result = Apply-ElmStyle -Content 'hi' -Width 2 -Style $style
            $lines = $result -split "`n"
            $lines[0] | Should -Be ''
            $lines[1] | Should -Be 'hi'
        }
    }

    Context 'When -Content is empty string' {
        It 'Should return empty string when no style' {
            $result = Apply-ElmStyle -Content '' -Style $null
            $result | Should -Be ''
        }

        It 'Should return padded spaces when padding is set' {
            $style = New-ElmStyle -Padding @(0, 1)
            $result = Apply-ElmStyle -Content '' -Width 0 -Style $style
            $result | Should -Be '  '
        }
    }
}
