BeforeAll {
    . $PSScriptRoot/../Private/Subscriptions/ConvertFrom-ElmKeyString.ps1
}

Describe 'ConvertFrom-ElmKeyString' -Tag 'Unit', 'P6' {

    Context 'Single letter key - no modifier' {
        It 'Should parse Q to ConsoleKey.Q with no modifiers' {
            $result = ConvertFrom-ElmKeyString -KeyString 'Q'
            $result.Key | Should -Be ([System.ConsoleKey]::Q)
            [int]$result.Modifiers | Should -Be 0
        }

        It 'Should be case-insensitive for key name' {
            $result = ConvertFrom-ElmKeyString -KeyString 'q'
            $result.Key | Should -Be ([System.ConsoleKey]::Q)
        }
    }

    Context 'Ctrl modifier' {
        It 'Should parse Ctrl+Q' {
            $result = ConvertFrom-ElmKeyString -KeyString 'Ctrl+Q'
            $result.Key       | Should -Be ([System.ConsoleKey]::Q)
            $result.Modifiers | Should -Be ([System.ConsoleModifiers]::Control)
        }

        It 'Should accept Control as a modifier alias' {
            $result = ConvertFrom-ElmKeyString -KeyString 'Control+C'
            $result.Modifiers | Should -Be ([System.ConsoleModifiers]::Control)
            $result.Key       | Should -Be ([System.ConsoleKey]::C)
        }

        It 'Should be case-insensitive for modifier prefix' {
            $result = ConvertFrom-ElmKeyString -KeyString 'ctrl+q'
            $result.Modifiers | Should -Be ([System.ConsoleModifiers]::Control)
        }
    }

    Context 'Alt modifier' {
        It 'Should parse Alt+F4' {
            $result = ConvertFrom-ElmKeyString -KeyString 'Alt+F4'
            $result.Key       | Should -Be ([System.ConsoleKey]::F4)
            $result.Modifiers | Should -Be ([System.ConsoleModifiers]::Alt)
        }
    }

    Context 'Shift modifier' {
        It 'Should parse Shift+Tab' {
            $result = ConvertFrom-ElmKeyString -KeyString 'Shift+Tab'
            $result.Key       | Should -Be ([System.ConsoleKey]::Tab)
            $result.Modifiers | Should -Be ([System.ConsoleModifiers]::Shift)
        }
    }

    Context 'Combined modifiers' {
        It 'Should parse Ctrl+Shift+N with both flags set' {
            $result = ConvertFrom-ElmKeyString -KeyString 'Ctrl+Shift+N'
            $result.Key | Should -Be ([System.ConsoleKey]::N)
            [int]$result.Modifiers | Should -Be (
                [int][System.ConsoleModifiers]::Control -bor [int][System.ConsoleModifiers]::Shift
            )
        }

        It 'Should parse Alt+Ctrl+Delete' {
            $result = ConvertFrom-ElmKeyString -KeyString 'Alt+Ctrl+Delete'
            $result.Key | Should -Be ([System.ConsoleKey]::Delete)
            [int]$result.Modifiers | Should -Be (
                [int][System.ConsoleModifiers]::Alt -bor [int][System.ConsoleModifiers]::Control
            )
        }
    }

    Context 'Special key names' {
        It 'Should parse UpArrow' {
            $result = ConvertFrom-ElmKeyString -KeyString 'UpArrow'
            $result.Key | Should -Be ([System.ConsoleKey]::UpArrow)
        }

        It 'Should parse Enter' {
            $result = ConvertFrom-ElmKeyString -KeyString 'Enter'
            $result.Key | Should -Be ([System.ConsoleKey]::Enter)
        }

        It 'Should parse Escape' {
            $result = ConvertFrom-ElmKeyString -KeyString 'Escape'
            $result.Key | Should -Be ([System.ConsoleKey]::Escape)
        }

        It 'Should parse Spacebar' {
            $result = ConvertFrom-ElmKeyString -KeyString 'Spacebar'
            $result.Key | Should -Be ([System.ConsoleKey]::Spacebar)
        }

        It 'Should parse F12' {
            $result = ConvertFrom-ElmKeyString -KeyString 'F12'
            $result.Key | Should -Be ([System.ConsoleKey]::F12)
        }

        It 'Should parse PageUp' {
            $result = ConvertFrom-ElmKeyString -KeyString 'PageUp'
            $result.Key | Should -Be ([System.ConsoleKey]::PageUp)
        }
    }

    Context 'Aliases' {
        It 'Should map Space to Spacebar' {
            $result = ConvertFrom-ElmKeyString -KeyString 'Space'
            $result.Key | Should -Be ([System.ConsoleKey]::Spacebar)
        }

        It 'Should map Esc to Escape' {
            $result = ConvertFrom-ElmKeyString -KeyString 'Esc'
            $result.Key | Should -Be ([System.ConsoleKey]::Escape)
        }

        It 'Should map Up to UpArrow' {
            $result = ConvertFrom-ElmKeyString -KeyString 'Up'
            $result.Key | Should -Be ([System.ConsoleKey]::UpArrow)
        }

        It 'Should map Down to DownArrow' {
            $result = ConvertFrom-ElmKeyString -KeyString 'Down'
            $result.Key | Should -Be ([System.ConsoleKey]::DownArrow)
        }

        It 'Should map Left to LeftArrow' {
            $result = ConvertFrom-ElmKeyString -KeyString 'Left'
            $result.Key | Should -Be ([System.ConsoleKey]::LeftArrow)
        }

        It 'Should map Right to RightArrow' {
            $result = ConvertFrom-ElmKeyString -KeyString 'Right'
            $result.Key | Should -Be ([System.ConsoleKey]::RightArrow)
        }

        It 'Should map Del to Delete' {
            $result = ConvertFrom-ElmKeyString -KeyString 'Del'
            $result.Key | Should -Be ([System.ConsoleKey]::Delete)
        }

        It 'Should map Return to Enter' {
            $result = ConvertFrom-ElmKeyString -KeyString 'Return'
            $result.Key | Should -Be ([System.ConsoleKey]::Enter)
        }

        It 'Should map PgUp to PageUp' {
            $result = ConvertFrom-ElmKeyString -KeyString 'PgUp'
            $result.Key | Should -Be ([System.ConsoleKey]::PageUp)
        }

        It 'Should map PgDn to PageDown' {
            $result = ConvertFrom-ElmKeyString -KeyString 'PgDn'
            $result.Key | Should -Be ([System.ConsoleKey]::PageDown)
        }

        It 'Should map digit 1 to D1' {
            $result = ConvertFrom-ElmKeyString -KeyString '1'
            $result.Key | Should -Be ([System.ConsoleKey]::D1)
        }

        It 'Should map digit 0 to D0' {
            $result = ConvertFrom-ElmKeyString -KeyString '0'
            $result.Key | Should -Be ([System.ConsoleKey]::D0)
        }
    }

    Context 'Pipeline input' {
        It 'Should accept string via pipeline' {
            $result = 'Q' | ConvertFrom-ElmKeyString
            $result.Key | Should -Be ([System.ConsoleKey]::Q)
        }

        It 'Should process multiple strings via pipeline' {
            $results = @('Q', 'W', 'E') | ConvertFrom-ElmKeyString
            $results.Count | Should -Be 3
            $results[0].Key | Should -Be ([System.ConsoleKey]::Q)
            $results[2].Key | Should -Be ([System.ConsoleKey]::E)
        }
    }

    Context 'Error handling' {
        It 'Should throw on unknown modifier' {
            { ConvertFrom-ElmKeyString -KeyString 'Meta+Q' } | Should -Throw
        }

        It 'Should throw on unknown key name' {
            { ConvertFrom-ElmKeyString -KeyString 'Blarg' } | Should -Throw
        }

        It 'Should throw on empty string' {
            { ConvertFrom-ElmKeyString -KeyString '' } | Should -Throw
        }
    }
}
