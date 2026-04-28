BeforeAll {
    . $PSScriptRoot/../Public/View/New-TeaSpinner.ps1
}

Describe 'New-TeaSpinner' -Tag 'Unit', 'P9' {

    Context 'Return value structure' {
        It 'Should return a Text node' {
            $s = New-TeaSpinner -Frame 0
            $s.Type | Should -Be 'Text'
        }

        It 'Should have a non-null Content property' {
            $s = New-TeaSpinner -Frame 0
            $s.Content | Should -Not -BeNull
        }

        It 'Should have Width Auto' {
            $s = New-TeaSpinner -Frame 0
            $s.Width | Should -Be 'Auto'
        }

        It 'Should have Height Auto' {
            $s = New-TeaSpinner -Frame 0
            $s.Height | Should -Be 'Auto'
        }
    }

    Context 'Dots variant (default)' {
        It 'Should return | for frame 0' {
            $s = New-TeaSpinner -Frame 0 -Variant Dots
            $s.Content | Should -Be '|'
        }

        It 'Should return / for frame 1' {
            $s = New-TeaSpinner -Frame 1 -Variant Dots
            $s.Content | Should -Be '/'
        }

        It 'Should return - for frame 2' {
            $s = New-TeaSpinner -Frame 2 -Variant Dots
            $s.Content | Should -Be '-'
        }

        It 'Should return \ for frame 3' {
            $s = New-TeaSpinner -Frame 3 -Variant Dots
            $s.Content | Should -Be '\'
        }

        It 'Should wrap around at frame 4 (back to |)' {
            $s = New-TeaSpinner -Frame 4 -Variant Dots
            $s.Content | Should -Be '|'
        }
    }

    Context 'Bounce variant' {
        It 'Should cycle through Bounce frames' {
            $frames = @('.', 'o', 'O', 'o')
            for ($i = 0; $i -lt $frames.Count; $i++) {
                $s = New-TeaSpinner -Frame $i -Variant Bounce
                $s.Content | Should -Be $frames[$i]
            }
        }
    }

    Context 'Arrow variant' {
        It 'Should return > for frame 0' {
            $s = New-TeaSpinner -Frame 0 -Variant Arrow
            $s.Content | Should -Be '>'
        }
    }

    Context 'Braille variant' {
        It 'Should return a non-empty string for frame 0' {
            $s = New-TeaSpinner -Frame 0 -Variant Braille
            $s.Content.Length | Should -BeGreaterThan 0
        }

        It 'Should cycle through all 10 braille frames' {
            $seen = @{}
            for ($i = 0; $i -lt 10; $i++) {
                $s = New-TeaSpinner -Frame $i -Variant Braille
                $seen[$s.Content] = $true
            }
            $seen.Count | Should -Be 10
        }
    }

    Context 'Custom Frames' {
        It 'Should use custom frames when provided' {
            $s = New-TeaSpinner -Frame 0 -Frames @('A', 'B', 'C')
            $s.Content | Should -Be 'A'
        }

        It 'Should cycle through custom frames' {
            $s2 = New-TeaSpinner -Frame 2 -Frames @('A', 'B', 'C')
            $s2.Content | Should -Be 'C'
        }

        It 'Should wrap custom frames' {
            $s3 = New-TeaSpinner -Frame 3 -Frames @('A', 'B', 'C')
            $s3.Content | Should -Be 'A'
        }
    }

    Context 'Large frame values' {
        It 'Should handle large frame values via modulo' {
            $s1 = New-TeaSpinner -Frame 0    -Variant Dots
            $s2 = New-TeaSpinner -Frame 1000 -Variant Dots
            # 1000 % 4 = 0
            $s2.Content | Should -Be $s1.Content
        }
    }

    Context 'Style passthrough' {
        It 'Should pass Style to the Text node' {
            $style = [PSCustomObject]@{ Foreground = 'Cyan' }
            $s     = New-TeaSpinner -Frame 0 -Style $style
            $s.Style | Should -Be $style
        }

        It 'Should have null Style when omitted' {
            $s = New-TeaSpinner -Frame 0
            $s.Style | Should -BeNullOrEmpty
        }
    }
}
