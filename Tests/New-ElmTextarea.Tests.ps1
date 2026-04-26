BeforeAll {
    . $PSScriptRoot/../Public/View/New-ElmTextarea.ps1
}

Describe 'New-ElmTextarea' -Tag 'Unit', 'P10' {

    Context 'Return value structure' {
        It 'Should return a Box node' {
            $ta = New-ElmTextarea -Lines @('hello')
            $ta.Type | Should -Be 'Box'
        }

        It 'Should have Direction Vertical' {
            $ta = New-ElmTextarea -Lines @('hello')
            $ta.Direction | Should -Be 'Vertical'
        }

        It 'Should have Width Auto' {
            $ta = New-ElmTextarea -Lines @('hello')
            $ta.Width | Should -Be 'Auto'
        }

        It 'Should have Height Auto' {
            $ta = New-ElmTextarea -Lines @('hello')
            $ta.Height | Should -Be 'Auto'
        }

        It 'Should have a Children array' {
            $ta = New-ElmTextarea -Lines @('hello')
            $ta.Children | Should -Not -BeNull
        }
    }

    Context 'Placeholder rendering' {
        It 'Should show placeholder as single Text child when Lines is empty string and not focused' {
            $ta = New-ElmTextarea -Lines @('') -Placeholder 'Type here...'
            $ta.Children[0].Content | Should -Be 'Type here...'
        }

        It 'Should NOT show placeholder when focused' {
            $ta = New-ElmTextarea -Lines @('') -Placeholder 'hint' -Focused
            $ta.Children[0].Content | Should -Be '|'
        }

        It 'Should NOT show placeholder when Lines has content' {
            $ta = New-ElmTextarea -Lines @('hello') -Placeholder 'hint'
            $ta.Children[0].Content | Should -Be 'hello'
        }

        It 'Should NOT show placeholder when Placeholder is empty string' {
            $ta = New-ElmTextarea -Lines @('')
            $ta.Children[0].Content | Should -Be ''
        }
    }

    Context 'Unfocused rendering' {
        It 'Should render each line as a separate Text child' {
            $ta = New-ElmTextarea -Lines @('line1', 'line2', 'line3')
            $ta.Children.Count | Should -Be 3
        }

        It 'Should render line content exactly' {
            $ta = New-ElmTextarea -Lines @('hello', 'world')
            $ta.Children[0].Content | Should -Be 'hello'
            $ta.Children[1].Content | Should -Be 'world'
        }

        It 'Should render empty line as empty string child' {
            $ta = New-ElmTextarea -Lines @('a', '', 'b')
            $ta.Children[1].Content | Should -Be ''
        }
    }

    Context 'Focused cursor rendering' {
        It 'Should insert cursor at end when CursorCol equals line length' {
            $ta = New-ElmTextarea -Lines @('hello') -CursorRow 0 -CursorCol 5 -Focused
            $ta.Children[0].Content | Should -Be 'hello|'
        }

        It 'Should insert cursor at beginning when CursorCol is 0' {
            $ta = New-ElmTextarea -Lines @('hello') -CursorRow 0 -CursorCol 0 -Focused
            $ta.Children[0].Content | Should -Be '|hello'
        }

        It 'Should insert cursor in middle of line' {
            $ta = New-ElmTextarea -Lines @('hello') -CursorRow 0 -CursorCol 2 -Focused
            $ta.Children[0].Content | Should -Be 'he|llo'
        }

        It 'Should only insert cursor on the CursorRow, not other lines' {
            $ta = New-ElmTextarea -Lines @('line1', 'line2', 'line3') -CursorRow 1 -CursorCol 2 -Focused
            $ta.Children[0].Content | Should -Be 'line1'
            $ta.Children[1].Content | Should -Be 'li|ne2'
            $ta.Children[2].Content | Should -Be 'line3'
        }

        It 'Should use custom CursorChar' {
            $ta = New-ElmTextarea -Lines @('hi') -CursorRow 0 -CursorCol 2 -Focused -CursorChar '_'
            $ta.Children[0].Content | Should -Be 'hi_'
        }
    }

    Context 'CursorRow and CursorCol clamping' {
        It 'Should clamp CursorRow below 0 to 0' {
            $ta = New-ElmTextarea -Lines @('a', 'b') -CursorRow -1 -CursorCol 0 -Focused
            $ta.Children[0].Content | Should -Be '|a'
        }

        It 'Should clamp CursorRow above last index to last index' {
            $ta = New-ElmTextarea -Lines @('a', 'b') -CursorRow 99 -CursorCol 0 -Focused
            $ta.Children[1].Content | Should -Be '|b'
        }

        It 'Should clamp CursorCol below 0 to 0' {
            $ta = New-ElmTextarea -Lines @('hello') -CursorRow 0 -CursorCol -5 -Focused
            $ta.Children[0].Content | Should -Be '|hello'
        }

        It 'Should clamp CursorCol above line length to line length' {
            $ta = New-ElmTextarea -Lines @('hi') -CursorRow 0 -CursorCol 99 -Focused
            $ta.Children[0].Content | Should -Be 'hi|'
        }
    }

    Context 'MaxVisible windowing' {
        It 'Should render only MaxVisible lines' {
            $lines = 1..10 | ForEach-Object { "Line $_" }
            $ta    = New-ElmTextarea -Lines $lines -MaxVisible 4
            $ta.Children.Count | Should -Be 4
        }

        It 'Should start window at ScrollOffset' {
            $ta = New-ElmTextarea -Lines @('A', 'B', 'C', 'D', 'E') -MaxVisible 3 -ScrollOffset 1
            $ta.Children[0].Content | Should -Be 'B'
        }

        It 'Should render all lines when count is within MaxVisible' {
            $ta = New-ElmTextarea -Lines @('X', 'Y') -MaxVisible 10
            $ta.Children.Count | Should -Be 2
        }
    }

    Context 'ScrollOffset clamping' {
        It 'Should clamp ScrollOffset below 0 to 0' {
            $ta = New-ElmTextarea -Lines @('A', 'B', 'C') -MaxVisible 2 -ScrollOffset -5
            $ta.Children[0].Content | Should -Be 'A'
        }

        It 'Should clamp ScrollOffset so window does not exceed line count' {
            $ta = New-ElmTextarea -Lines @('A', 'B', 'C') -MaxVisible 2 -ScrollOffset 99
            $ta.Children[0].Content | Should -Be 'B'
        }
    }

    Context 'Style passthrough' {
        It 'Should apply Style to lines when not focused' {
            $s  = [PSCustomObject]@{ Foreground = 'White' }
            $ta = New-ElmTextarea -Lines @('hello') -Style $s
            $ta.Children[0].Style | Should -Be $s
        }

        It 'Should apply FocusedStyle to lines when focused and FocusedStyle is set' {
            $fs = [PSCustomObject]@{ Foreground = 'BrightWhite' }
            $ta = New-ElmTextarea -Lines @('hello') -CursorRow 0 -CursorCol 0 -Focused -FocusedStyle $fs
            $ta.Children[0].Style | Should -Be $fs
        }

        It 'Should fall back to Style when Focused but FocusedStyle is null' {
            $s  = [PSCustomObject]@{ Foreground = 'White' }
            $ta = New-ElmTextarea -Lines @('hello') -CursorRow 0 -CursorCol 0 -Focused -Style $s
            $ta.Children[0].Style | Should -Be $s
        }
    }

    Context 'FocusedBoxStyle - outer Box style when focused' {
        It 'Should apply FocusedBoxStyle to the outer Box when focused' {
            $fbs = [PSCustomObject]@{ Border = 'Rounded' }
            $ta  = New-ElmTextarea -Lines @('hello') -CursorRow 0 -CursorCol 0 -Focused -FocusedBoxStyle $fbs
            $ta.Style | Should -Be $fbs
        }

        It 'Should still return a Box/Vertical node when FocusedBoxStyle is provided' {
            $fbs = [PSCustomObject]@{ Border = 'Rounded' }
            $ta  = New-ElmTextarea -Lines @('hello') -CursorRow 0 -CursorCol 0 -Focused -FocusedBoxStyle $fbs
            $ta.Type      | Should -Be 'Box'
            $ta.Direction | Should -Be 'Vertical'
        }

        It 'Should still render text children when FocusedBoxStyle is provided' {
            $fbs = [PSCustomObject]@{ Border = 'Rounded' }
            $ta  = New-ElmTextarea -Lines @('hello') -CursorRow 0 -CursorCol 5 -Focused -FocusedBoxStyle $fbs
            $ta.Children[0].Content | Should -Be 'hello|'
        }

        It 'Should have null outer Box Style when focused but FocusedBoxStyle is null' {
            $ta = New-ElmTextarea -Lines @('hello') -CursorRow 0 -CursorCol 0 -Focused
            $ta.Style | Should -BeNullOrEmpty
        }

        It 'Should have null outer Box Style when unfocused even if FocusedBoxStyle is provided' {
            $fbs = [PSCustomObject]@{ Border = 'Rounded' }
            $ta  = New-ElmTextarea -Lines @('hello') -FocusedBoxStyle $fbs
            $ta.Style | Should -BeNullOrEmpty
        }

        It 'Should keep FocusedStyle on text children independently of FocusedBoxStyle' {
            $fbs = [PSCustomObject]@{ Border = 'Rounded' }
            $fs  = [PSCustomObject]@{ Foreground = 'BrightWhite' }
            $ta  = New-ElmTextarea -Lines @('hello') -CursorRow 0 -CursorCol 0 -Focused -FocusedBoxStyle $fbs -FocusedStyle $fs
            $ta.Children[0].Style | Should -Be $fs
        }
    }
}
