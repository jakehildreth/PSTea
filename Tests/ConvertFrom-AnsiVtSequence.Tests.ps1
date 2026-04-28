BeforeAll {
    . $PSScriptRoot/../Private/Web/ConvertFrom-AnsiCsi.ps1
    . $PSScriptRoot/../Private/Web/ConvertFrom-AnsiModCode.ps1
    . $PSScriptRoot/../Private/Web/ConvertFrom-AnsiCharToConsoleKey.ps1
    . $PSScriptRoot/../Private/Web/ConvertFrom-AnsiVtSequence.ps1
}

Describe 'ConvertFrom-AnsiVtSequence' {

    Context 'Printable ASCII' {
        It 'Should map lowercase a-z to KeyDown events' {
            $result = ConvertFrom-AnsiVtSequence -InputString 'a'
            $result.Count  | Should -Be 1
            $result[0].Type | Should -Be 'KeyDown'
            $result[0].Char | Should -Be 'a'
        }

        It 'Should map uppercase A to KeyDown with Shift modifier' {
            $result = ConvertFrom-AnsiVtSequence -InputString 'A'
            $result[0].Modifiers -band [System.ConsoleModifiers]::Shift | Should -Not -Be 0
        }

        It 'Should map the space character' {
            $result = ConvertFrom-AnsiVtSequence -InputString ' '
            $result.Count  | Should -Be 1
            $result[0].Type | Should -Be 'KeyDown'
            $result[0].Char | Should -Be ' '
        }

        It 'Should handle a multi-character printable string' {
            $result = ConvertFrom-AnsiVtSequence -InputString 'hi'
            $result.Count | Should -Be 2
        }
    }

    Context 'Control characters' {
        It 'Should map Ctrl+C (0x03) to ConsoleKey C with Control modifier' {
            $input = [char]0x03
            $result = ConvertFrom-AnsiVtSequence -InputString $input
            $result.Count | Should -Be 1
            $result[0].Key      | Should -Be ([System.ConsoleKey]::C)
            $result[0].Modifiers -band [System.ConsoleModifiers]::Control | Should -Not -Be 0
        }

        It 'Should map Enter (0x0D) to ConsoleKey Enter' {
            $input = [char]0x0D
            $result = ConvertFrom-AnsiVtSequence -InputString $input
            $result[0].Key | Should -Be ([System.ConsoleKey]::Enter)
        }

        It 'Should map Backspace (0x7F) to ConsoleKey Backspace' {
            $input = [char]0x7F
            $result = ConvertFrom-AnsiVtSequence -InputString $input
            $result[0].Key | Should -Be ([System.ConsoleKey]::Backspace)
        }

        It 'Should map Tab (0x09) to ConsoleKey Tab' {
            $input = [char]0x09
            $result = ConvertFrom-AnsiVtSequence -InputString $input
            $result[0].Key | Should -Be ([System.ConsoleKey]::Tab)
        }
    }

    Context 'Escape and CSI sequences' {
        It 'Should map ESC alone to ConsoleKey Escape' {
            $input = [char]0x1b
            $result = ConvertFrom-AnsiVtSequence -InputString $input
            $result[0].Key | Should -Be ([System.ConsoleKey]::Escape)
        }

        It 'Should map ESC[A to UpArrow' {
            $input = [char]0x1b + '[A'
            $result = ConvertFrom-AnsiVtSequence -InputString $input
            $result[0].Key | Should -Be ([System.ConsoleKey]::UpArrow)
        }

        It 'Should map ESC[B to DownArrow' {
            $input = [char]0x1b + '[B'
            $result = ConvertFrom-AnsiVtSequence -InputString $input
            $result[0].Key | Should -Be ([System.ConsoleKey]::DownArrow)
        }

        It 'Should map ESC[C to RightArrow' {
            $input = [char]0x1b + '[C'
            $result = ConvertFrom-AnsiVtSequence -InputString $input
            $result[0].Key | Should -Be ([System.ConsoleKey]::RightArrow)
        }

        It 'Should map ESC[D to LeftArrow' {
            $input = [char]0x1b + '[D'
            $result = ConvertFrom-AnsiVtSequence -InputString $input
            $result[0].Key | Should -Be ([System.ConsoleKey]::LeftArrow)
        }

        It 'Should map ESC[H to Home' {
            $input = [char]0x1b + '[H'
            $result = ConvertFrom-AnsiVtSequence -InputString $input
            $result[0].Key | Should -Be ([System.ConsoleKey]::Home)
        }

        It 'Should map ESC[F to End' {
            $input = [char]0x1b + '[F'
            $result = ConvertFrom-AnsiVtSequence -InputString $input
            $result[0].Key | Should -Be ([System.ConsoleKey]::End)
        }

        It 'Should map ESC[5~ to PageUp' {
            $input = [char]0x1b + '[5~'
            $result = ConvertFrom-AnsiVtSequence -InputString $input
            $result[0].Key | Should -Be ([System.ConsoleKey]::PageUp)
        }

        It 'Should map ESC[6~ to PageDown' {
            $input = [char]0x1b + '[6~'
            $result = ConvertFrom-AnsiVtSequence -InputString $input
            $result[0].Key | Should -Be ([System.ConsoleKey]::PageDown)
        }

        It 'Should map ESC[3~ to Delete' {
            $input = [char]0x1b + '[3~'
            $result = ConvertFrom-AnsiVtSequence -InputString $input
            $result[0].Key | Should -Be ([System.ConsoleKey]::Delete)
        }

        It 'Should map ESC[2~ to Insert' {
            $input = [char]0x1b + '[2~'
            $result = ConvertFrom-AnsiVtSequence -InputString $input
            $result[0].Key | Should -Be ([System.ConsoleKey]::Insert)
        }
    }

    Context 'Modified sequences (Shift/Ctrl/Alt)' {
        It 'Should map ESC[1;2A (Shift+UpArrow) with Shift modifier' {
            $input = [char]0x1b + '[1;2A'
            $result = ConvertFrom-AnsiVtSequence -InputString $input
            $result[0].Key | Should -Be ([System.ConsoleKey]::UpArrow)
            $result[0].Modifiers -band [System.ConsoleModifiers]::Shift | Should -Not -Be 0
        }

        It 'Should map ESC[1;5C (Ctrl+RightArrow) with Control modifier' {
            $input = [char]0x1b + '[1;5C'
            $result = ConvertFrom-AnsiVtSequence -InputString $input
            $result[0].Key | Should -Be ([System.ConsoleKey]::RightArrow)
            $result[0].Modifiers -band [System.ConsoleModifiers]::Control | Should -Not -Be 0
        }
    }

    Context 'Resize sequences' {
        It 'Should parse ESC[8;50;220t as Resize with Width=220 Height=50' {
            $input = [char]0x1b + '[8;50;220t'
            $result = ConvertFrom-AnsiVtSequence -InputString $input
            $result[0].Type   | Should -Be 'Resize'
            $result[0].Width  | Should -Be 220
            $result[0].Height | Should -Be 50
        }
    }

    Context 'Output shape' {
        It 'Should return PSCustomObject with Type, Key, Char, Modifiers for KeyDown' {
            $result = ConvertFrom-AnsiVtSequence -InputString 'x'
            $result[0].PSObject.Properties.Name | Should -Contain 'Type'
            $result[0].PSObject.Properties.Name | Should -Contain 'Key'
            $result[0].PSObject.Properties.Name | Should -Contain 'Char'
            $result[0].PSObject.Properties.Name | Should -Contain 'Modifiers'
        }

        It 'Should return an empty array for empty string' {
            $result = ConvertFrom-AnsiVtSequence -InputString ''
            $result.Count | Should -Be 0
        }

        It 'Should return an empty array for null' {
            $result = ConvertFrom-AnsiVtSequence -InputString $null
            $result.Count | Should -Be 0
        }
    }
}
