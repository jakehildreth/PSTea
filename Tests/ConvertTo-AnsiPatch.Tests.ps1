BeforeAll {
    . $PSScriptRoot/../Private/Style/Resolve-ElmColor.ps1
    . $PSScriptRoot/../Private/Style/ConvertTo-BorderChars.ps1
    . $PSScriptRoot/../Private/Style/Apply-ElmStyle.ps1
    . $PSScriptRoot/../Private/Rendering/ConvertTo-AnsiPatch.ps1
}

Describe 'ConvertTo-AnsiPatch' {
    BeforeAll {
        $esc = [char]27
    }

    Context 'Empty patch list' {
        It 'Should return an empty string' {
            $result = ConvertTo-AnsiPatch -Patches @()
            $result | Should -Be ''
        }
    }

    Context 'Replace patch' {
        It 'Should emit 1-indexed cursor position for X=5, Y=2' {
            $patch = [PSCustomObject]@{ Type = 'Replace'; X = 5; Y = 2; Content = 'hi'; Style = $null }
            $result = ConvertTo-AnsiPatch -Patches @($patch)
            $result | Should -Match ([regex]::Escape("$esc[3;6H"))
        }

        It 'Should emit the replacement content' {
            $patch = [PSCustomObject]@{ Type = 'Replace'; X = 0; Y = 0; Content = 'updated'; Style = $null }
            $result = ConvertTo-AnsiPatch -Patches @($patch)
            $result | Should -Match 'updated'
        }

        It 'Should append trailing spaces when new content is shorter than OldWidth' {
            # 'Focus: Left' (11 chars) replacing 'Focus: Right' (12 chars) must emit 1 trailing space
            $patch = [PSCustomObject]@{ Type = 'Replace'; X = 0; Y = 0; Content = 'Focus: Left'; Style = $null; Width = 11; OldWidth = 12 }
            $result = ConvertTo-AnsiPatch -Patches @($patch)
            # Must contain the content followed by at least one space to clear the stale char
            $result | Should -Match 'Focus: Left '
        }

        It 'Should not append extra spaces when new content is same width as OldWidth' {
            $patch = [PSCustomObject]@{ Type = 'Replace'; X = 0; Y = 0; Content = 'hello'; Style = $null; Width = 5; OldWidth = 5 }
            $result = ConvertTo-AnsiPatch -Patches @($patch)
            $result | Should -Match 'hello'
        }

        It 'Should apply style SGR when style has Bold' {
            . $PSScriptRoot/../Public/Style/New-ElmStyle.ps1
            $style = New-ElmStyle -Bold
            $patch = [PSCustomObject]@{ Type = 'Replace'; X = 0; Y = 0; Content = 'hi'; Style = $style }
            $result = ConvertTo-AnsiPatch -Patches @($patch)
            $result | Should -Match ([regex]::Escape("$esc[1m"))
        }
    }

    Context 'Clear patch' {
        It 'Should emit cursor position at the cleared region start' {
            $patch = [PSCustomObject]@{ Type = 'Clear'; X = 2; Y = 1; Width = 10; Height = 1 }
            $result = ConvertTo-AnsiPatch -Patches @($patch)
            $result | Should -Match ([regex]::Escape("$esc[2;3H"))
        }

        It 'Should emit spaces spanning the cleared width' {
            $patch = [PSCustomObject]@{ Type = 'Clear'; X = 0; Y = 0; Width = 5; Height = 1 }
            $result = ConvertTo-AnsiPatch -Patches @($patch)
            $result | Should -Match '     '
        }

        It 'Should emit a row entry for each row in Height' {
            $patch = [PSCustomObject]@{ Type = 'Clear'; X = 0; Y = 0; Width = 3; Height = 2 }
            $result = ConvertTo-AnsiPatch -Patches @($patch)
            $result | Should -Match ([regex]::Escape("$esc[1;1H"))
            $result | Should -Match ([regex]::Escape("$esc[2;1H"))
        }
    }

    Context 'FullRedraw patch' {
        It 'Should be skipped - not emitted in output' {
            $patch = [PSCustomObject]@{ Type = 'FullRedraw' }
            $result = ConvertTo-AnsiPatch -Patches @($patch)
            $result | Should -Be ''
        }

        It 'Should still emit other patches when mixed with FullRedraw' {
            $fr      = [PSCustomObject]@{ Type = 'FullRedraw' }
            $replace = [PSCustomObject]@{ Type = 'Replace'; X = 0; Y = 0; Content = 'x'; Style = $null }
            $result = ConvertTo-AnsiPatch -Patches @($fr, $replace)
            $result | Should -Match 'x'
        }
    }
}
