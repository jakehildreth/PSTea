BeforeAll {
    . $PSScriptRoot/../Public/View/New-ElmTextInput.ps1
}

Describe 'New-ElmTextInput' -Tag 'Unit', 'P9' {

    Context 'Return value structure' {
        It 'Should return a Text node' {
            $ti = New-ElmTextInput -Value 'hello'
            $ti.Type | Should -Be 'Text'
        }

        It 'Should have Width Auto' {
            $ti = New-ElmTextInput -Value 'hello'
            $ti.Width | Should -Be 'Auto'
        }

        It 'Should have Height Auto' {
            $ti = New-ElmTextInput -Value 'hello'
            $ti.Height | Should -Be 'Auto'
        }
    }

    Context 'Unfocused rendering' {
        It 'Should show Value when not focused' {
            $ti = New-ElmTextInput -Value 'hello'
            $ti.Content | Should -Be 'hello'
        }

        It 'Should show empty string when Value is empty and no Placeholder' {
            $ti = New-ElmTextInput -Value ''
            $ti.Content | Should -Be ''
        }

        It 'Should show Placeholder when Value is empty and unfocused' {
            $ti = New-ElmTextInput -Value '' -Placeholder 'Search...'
            $ti.Content | Should -Be 'Search...'
        }

        It 'Should NOT show Placeholder when Value is non-empty' {
            $ti = New-ElmTextInput -Value 'hi' -Placeholder 'Search...'
            $ti.Content | Should -Be 'hi'
        }
    }

    Context 'Focused rendering' {
        It 'Should insert cursor at end when CursorPos equals Value.Length' {
            $ti = New-ElmTextInput -Value 'hello' -CursorPos 5 -Focused
            $ti.Content | Should -Be 'hello|'
        }

        It 'Should insert cursor at beginning when CursorPos is 0' {
            $ti = New-ElmTextInput -Value 'hello' -CursorPos 0 -Focused
            $ti.Content | Should -Be '|hello'
        }

        It 'Should insert cursor in middle' {
            $ti = New-ElmTextInput -Value 'hello' -CursorPos 2 -Focused
            $ti.Content | Should -Be 'he|llo'
        }

        It 'Should use custom CursorChar' {
            $ti = New-ElmTextInput -Value 'hi' -CursorPos 2 -Focused -CursorChar '_'
            $ti.Content | Should -Be 'hi_'
        }

        It 'Should NOT show Placeholder when focused even if Value is empty' {
            $ti = New-ElmTextInput -Value '' -CursorPos 0 -Focused -Placeholder 'hint'
            $ti.Content | Should -Be '|'
        }
    }

    Context 'CursorPos clamping' {
        It 'Should clamp CursorPos below 0 to 0' {
            $ti = New-ElmTextInput -Value 'abc' -CursorPos -5 -Focused
            $ti.Content | Should -Be '|abc'
        }

        It 'Should clamp CursorPos above Value.Length to Value.Length' {
            $ti = New-ElmTextInput -Value 'abc' -CursorPos 99 -Focused
            $ti.Content | Should -Be 'abc|'
        }
    }

    Context 'Style passthrough' {
        It 'Should apply Style when unfocused' {
            $style = [PSCustomObject]@{ Foreground = 'White' }
            $ti    = New-ElmTextInput -Value 'x' -Style $style
            $ti.Style | Should -Be $style
        }

        It 'Should apply FocusedStyle when focused' {
            $base  = [PSCustomObject]@{ Foreground = 'White' }
            $focus = [PSCustomObject]@{ Foreground = 'BrightWhite'; Underline = $true }
            $ti    = New-ElmTextInput -Value 'x' -CursorPos 1 -Focused -Style $base -FocusedStyle $focus
            $ti.Style | Should -Be $focus
        }

        It 'Should fall back to Style when focused but FocusedStyle omitted' {
            $style = [PSCustomObject]@{ Foreground = 'White' }
            $ti    = New-ElmTextInput -Value 'x' -CursorPos 1 -Focused -Style $style
            $ti.Style | Should -Be $style
        }

        It 'Should have null Style when no style params provided' {
            $ti = New-ElmTextInput -Value 'x'
            $ti.Style | Should -BeNullOrEmpty
        }
    }

    Context 'FocusedBoxStyle — wrapper Box when focused' {
        It 'Should return a Box node when focused and FocusedBoxStyle is provided' {
            $fbs = [PSCustomObject]@{ Border = 'Rounded' }
            $ti  = New-ElmTextInput -Value 'hi' -CursorPos 2 -Focused -FocusedBoxStyle $fbs
            $ti.Type | Should -Be 'Box'
        }

        It 'Should have Direction Vertical on the wrapper Box' {
            $fbs = [PSCustomObject]@{ Border = 'Rounded' }
            $ti  = New-ElmTextInput -Value 'hi' -CursorPos 2 -Focused -FocusedBoxStyle $fbs
            $ti.Direction | Should -Be 'Vertical'
        }

        It 'Should apply FocusedBoxStyle as the wrapper Box Style' {
            $fbs = [PSCustomObject]@{ Border = 'Rounded' }
            $ti  = New-ElmTextInput -Value 'hi' -CursorPos 2 -Focused -FocusedBoxStyle $fbs
            $ti.Style | Should -Be $fbs
        }

        It 'Should wrap a single Text child inside the Box' {
            $fbs = [PSCustomObject]@{ Border = 'Rounded' }
            $ti  = New-ElmTextInput -Value 'hi' -CursorPos 2 -Focused -FocusedBoxStyle $fbs
            $ti.Children.Count | Should -Be 1
            $ti.Children[0].Type | Should -Be 'Text'
        }

        It 'Should place the rendered content inside the child Text node' {
            $fbs = [PSCustomObject]@{ Border = 'Rounded' }
            $ti  = New-ElmTextInput -Value 'hi' -CursorPos 2 -Focused -FocusedBoxStyle $fbs
            $ti.Children[0].Content | Should -Be 'hi|'
        }

        It 'Should apply FocusedStyle to the inner Text node when both are provided' {
            $fbs = [PSCustomObject]@{ Border = 'Rounded' }
            $fs  = [PSCustomObject]@{ Foreground = 'BrightWhite' }
            $ti  = New-ElmTextInput -Value 'hi' -CursorPos 0 -Focused -FocusedBoxStyle $fbs -FocusedStyle $fs
            $ti.Children[0].Style | Should -Be $fs
        }

        It 'Should NOT return a Box when focused but FocusedBoxStyle is null' {
            $ti = New-ElmTextInput -Value 'hi' -CursorPos 2 -Focused
            $ti.Type | Should -Be 'Text'
        }

        It 'Should NOT return a Box when unfocused even if FocusedBoxStyle is provided' {
            $fbs = [PSCustomObject]@{ Border = 'Rounded' }
            $ti  = New-ElmTextInput -Value 'hi' -FocusedBoxStyle $fbs
            $ti.Type | Should -Be 'Text'
        }
    }
}
