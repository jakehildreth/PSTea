BeforeAll {
    . $PSScriptRoot/../Private/Style/ConvertTo-BorderChars.ps1
}

Describe 'ConvertTo-BorderChars' -Tag 'Unit', 'P2' {
    Context 'When given None' {
        It 'Should return all empty strings' {
            $result = ConvertTo-BorderChars -Style 'None'
            $result.TL | Should -Be ''
            $result.T  | Should -Be ''
            $result.TR | Should -Be ''
            $result.L  | Should -Be ''
            $result.R  | Should -Be ''
            $result.BL | Should -Be ''
            $result.B  | Should -Be ''
            $result.BR | Should -Be ''
        }
    }

    Context 'When given Normal' {
        It 'Should return correct box-drawing chars' {
            $result = ConvertTo-BorderChars -Style 'Normal'
            $result.TL | Should -Be '┌'
            $result.T  | Should -Be '─'
            $result.TR | Should -Be '┐'
            $result.L  | Should -Be '│'
            $result.R  | Should -Be '│'
            $result.BL | Should -Be '└'
            $result.B  | Should -Be '─'
            $result.BR | Should -Be '┘'
        }
    }

    Context 'When given Rounded' {
        It 'Should return correct corner chars' {
            $result = ConvertTo-BorderChars -Style 'Rounded'
            $result.TL | Should -Be '╭'
            $result.TR | Should -Be '╮'
            $result.BL | Should -Be '╰'
            $result.BR | Should -Be '╯'
        }

        It 'Should use normal horizontal/vertical chars' {
            $result = ConvertTo-BorderChars -Style 'Rounded'
            $result.T | Should -Be '─'
            $result.L | Should -Be '│'
        }
    }

    Context 'When given Thick' {
        It 'Should return correct box-drawing chars' {
            $result = ConvertTo-BorderChars -Style 'Thick'
            $result.TL | Should -Be '┏'
            $result.T  | Should -Be '━'
            $result.TR | Should -Be '┓'
            $result.L  | Should -Be '┃'
            $result.R  | Should -Be '┃'
            $result.BL | Should -Be '┗'
            $result.B  | Should -Be '━'
            $result.BR | Should -Be '┛'
        }
    }

    Context 'When given Double' {
        It 'Should return correct box-drawing chars' {
            $result = ConvertTo-BorderChars -Style 'Double'
            $result.TL | Should -Be '╔'
            $result.T  | Should -Be '═'
            $result.TR | Should -Be '╗'
            $result.L  | Should -Be '║'
            $result.R  | Should -Be '║'
            $result.BL | Should -Be '╚'
            $result.B  | Should -Be '═'
            $result.BR | Should -Be '╝'
        }
    }

    Context 'When given an unknown style' {
        It 'Should return None chars (all empty strings)' {
            $result = ConvertTo-BorderChars -Style 'Unknown' -ErrorAction SilentlyContinue
            $result.TL | Should -Be ''
        }

        It 'Should emit a non-terminating error' {
            { ConvertTo-BorderChars -Style 'Unknown' -ErrorAction Stop } | Should -Throw
        }
    }
}
