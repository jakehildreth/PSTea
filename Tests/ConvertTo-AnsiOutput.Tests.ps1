BeforeAll {
    . $PSScriptRoot/../Private/Style/Resolve-ElmColor.ps1
    . $PSScriptRoot/../Private/Style/ConvertTo-BorderChars.ps1
    . $PSScriptRoot/../Private/Style/Apply-ElmStyle.ps1
    . $PSScriptRoot/../Private/Rendering/ConvertTo-AnsiOutput.ps1
}

Describe 'ConvertTo-AnsiOutput' {
    BeforeAll {
        $esc = [char]27
    }

    Context 'Single Text node at origin' {
        It 'Should contain ESC[1;1H for a node at X=0, Y=0' {
            $node = [PSCustomObject]@{ Type = 'Text'; Content = 'hello'; Style = $null; Width = 5; Height = 1; X = 0; Y = 0 }
            $result = ConvertTo-AnsiOutput -Root $node
            $result | Should -Match ([regex]::Escape("$esc[1;1H"))
        }

        It 'Should contain the content string' {
            $node = [PSCustomObject]@{ Type = 'Text'; Content = 'hello'; Style = $null; Width = 5; Height = 1; X = 0; Y = 0 }
            $result = ConvertTo-AnsiOutput -Root $node
            $result | Should -Match 'hello'
        }

        It 'Should include hide-cursor sequence' {
            $node = [PSCustomObject]@{ Type = 'Text'; Content = 'hello'; Style = $null; Width = 5; Height = 1; X = 0; Y = 0 }
            $result = ConvertTo-AnsiOutput -Root $node
            $result | Should -Match ([regex]::Escape("$esc[?25l"))
        }

        It 'Should include clear-screen sequence' {
            $node = [PSCustomObject]@{ Type = 'Text'; Content = 'hello'; Style = $null; Width = 5; Height = 1; X = 0; Y = 0 }
            $result = ConvertTo-AnsiOutput -Root $node
            $result | Should -Match ([regex]::Escape("$esc[2J"))
        }

        It 'Should include show-cursor sequence at end' {
            $node = [PSCustomObject]@{ Type = 'Text'; Content = 'hello'; Style = $null; Width = 5; Height = 1; X = 0; Y = 0 }
            $result = ConvertTo-AnsiOutput -Root $node
            $result | Should -Match ([regex]::Escape("$esc[?25h"))
        }
    }

    Context 'Text node at non-origin position' {
        It 'Should emit correct 1-indexed cursor position' {
            $node = [PSCustomObject]@{ Type = 'Text'; Content = 'hi'; Style = $null; Width = 2; Height = 1; X = 5; Y = 3 }
            $result = ConvertTo-AnsiOutput -Root $node
            $result | Should -Match ([regex]::Escape("$esc[4;6H"))
        }
    }

    Context 'Text node with style' {
        It 'Should contain an SGR escape sequence when Bold style is applied' {
            . $PSScriptRoot/../Public/Style/New-ElmStyle.ps1
            $style = New-ElmStyle -Bold
            $node  = [PSCustomObject]@{ Type = 'Text'; Content = 'hi'; Style = $style; Width = 2; Height = 1; X = 0; Y = 0 }
            $result = ConvertTo-AnsiOutput -Root $node
            # Bold = ESC[1m
            $result | Should -Match ([regex]::Escape("$esc[1m"))
        }
    }

    Context 'Box containing two Text nodes at different positions' {
        It 'Should contain cursor-position sequences for both children' {
            $t1   = [PSCustomObject]@{ Type = 'Text'; Content = 'a'; Style = $null; Width = 1; Height = 1; X = 0; Y = 0 }
            $t2   = [PSCustomObject]@{ Type = 'Text'; Content = 'b'; Style = $null; Width = 1; Height = 1; X = 0; Y = 1 }
            $root = [PSCustomObject]@{ Type = 'Box'; Direction = 'Vertical'; Children = @($t1, $t2); Style = $null; Width = 10; Height = 2; X = 0; Y = 0 }
            $result = ConvertTo-AnsiOutput -Root $root
            $result | Should -Match ([regex]::Escape("$esc[1;1H"))
            $result | Should -Match ([regex]::Escape("$esc[2;1H"))
        }
    }
}
