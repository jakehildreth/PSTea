BeforeAll {
    . $PSScriptRoot/../Private/Style/Resolve-ElmColor.ps1
    $esc = [char]27
}

Describe 'Resolve-ElmColor' -Tag 'Unit', 'P2' {
    Context 'When given a hex color string' {
        It 'Should return truecolor fg sequence for #FF0000' {
            $result = Resolve-ElmColor -Color '#FF0000' -IsForeground
            $result | Should -Be "$($esc)[38;2;255;0;0m"
        }

        It 'Should return truecolor bg sequence for #FF0000' {
            $result = Resolve-ElmColor -Color '#FF0000'
            $result | Should -Be "$($esc)[48;2;255;0;0m"
        }

        It 'Should handle lowercase hex' {
            $result = Resolve-ElmColor -Color '#00ff00' -IsForeground
            $result | Should -Be "$($esc)[38;2;0;255;0m"
        }

        It 'Should parse all three RGB components correctly' {
            $result = Resolve-ElmColor -Color '#1A2B3C' -IsForeground
            $result | Should -Be "$($esc)[38;2;26;43;60m"
        }
    }

    Context 'When given a 256-index integer' {
        It 'Should return 256-color fg sequence for 196' {
            $result = Resolve-ElmColor -Color 196 -IsForeground
            $result | Should -Be "$($esc)[38;5;196m"
        }

        It 'Should return 256-color bg sequence for 196' {
            $result = Resolve-ElmColor -Color 196
            $result | Should -Be "$($esc)[48;5;196m"
        }

        It 'Should return 256-color fg sequence for 0' {
            $result = Resolve-ElmColor -Color 0 -IsForeground
            $result | Should -Be "$($esc)[38;5;0m"
        }
    }

    Context 'When given a named color' {
        It 'Should return correct fg sequence for Red' {
            $result = Resolve-ElmColor -Color 'Red' -IsForeground
            $result | Should -Be "$($esc)[31m"
        }

        It 'Should return correct bg sequence for Blue' {
            $result = Resolve-ElmColor -Color 'Blue'
            $result | Should -Be "$($esc)[44m"
        }

        It 'Should return correct fg sequence for BrightGreen' {
            $result = Resolve-ElmColor -Color 'BrightGreen' -IsForeground
            $result | Should -Be "$($esc)[92m"
        }

        It 'Should return correct bg sequence for BrightWhite' {
            $result = Resolve-ElmColor -Color 'BrightWhite'
            $result | Should -Be "$($esc)[107m"
        }
    }

    Context 'When given an invalid color string' {
        It 'Should return an empty string' {
            $result = Resolve-ElmColor -Color 'NotAColor' -IsForeground -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }

        It 'Should emit a non-terminating error' {
            { Resolve-ElmColor -Color 'NotAColor' -IsForeground -ErrorAction Stop } | Should -Throw
        }
    }
}
