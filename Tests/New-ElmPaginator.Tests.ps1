BeforeAll {
    . $PSScriptRoot/../Public/View/New-ElmPaginator.ps1
}

Describe 'New-ElmPaginator' -Tag 'Unit', 'P10' {

    Context 'Numeric mode - return value structure' {
        It 'Should return a Text node' {
            $p = New-ElmPaginator -CurrentPage 3 -PageCount 7
            $p.Type | Should -Be 'Text'
        }

        It 'Should have Width Auto' {
            $p = New-ElmPaginator -CurrentPage 1 -PageCount 5
            $p.Width | Should -Be 'Auto'
        }

        It 'Should have Height Auto' {
            $p = New-ElmPaginator -CurrentPage 1 -PageCount 5
            $p.Height | Should -Be 'Auto'
        }
    }

    Context 'Numeric mode - content' {
        It 'Should include current page number' {
            $p = New-ElmPaginator -CurrentPage 3 -PageCount 7
            $p.Content | Should -Match '3'
        }

        It 'Should include total page count' {
            $p = New-ElmPaginator -CurrentPage 3 -PageCount 7
            $p.Content | Should -Match '7'
        }

        It 'Should show < when not on first page' {
            $p = New-ElmPaginator -CurrentPage 2 -PageCount 5
            $p.Content | Should -Match '<'
        }

        It 'Should NOT show < on the first page' {
            $p = New-ElmPaginator -CurrentPage 1 -PageCount 5
            $p.Content | Should -Not -Match '<'
        }

        It 'Should show > when not on the last page' {
            $p = New-ElmPaginator -CurrentPage 2 -PageCount 5
            $p.Content | Should -Match '>'
        }

        It 'Should NOT show > on the last page' {
            $p = New-ElmPaginator -CurrentPage 5 -PageCount 5
            $p.Content | Should -Not -Match '>'
        }

        It 'Should show a space in place of < on the first page' {
            $p = New-ElmPaginator -CurrentPage 1 -PageCount 3
            $p.Content | Should -Match '^\s'
        }
    }

    Context 'Numeric mode - clamping' {
        It 'Should clamp CurrentPage below 1 to 1' {
            $p = New-ElmPaginator -CurrentPage -5 -PageCount 5
            $p.Content | Should -Match ' 1 '
        }

        It 'Should clamp CurrentPage above PageCount to PageCount' {
            $p = New-ElmPaginator -CurrentPage 99 -PageCount 5
            $p.Content | Should -Match ' 5 '
        }
    }

    Context 'Tabs mode - return value structure' {
        It 'Should return a Box node' {
            $p = New-ElmPaginator -Tabs @('A', 'B', 'C') -ActiveTab 0
            $p.Type | Should -Be 'Box'
        }

        It 'Should have Direction Horizontal' {
            $p = New-ElmPaginator -Tabs @('A', 'B', 'C') -ActiveTab 0
            $p.Direction | Should -Be 'Horizontal'
        }

        It 'Should have Width Auto' {
            $p = New-ElmPaginator -Tabs @('A', 'B') -ActiveTab 0
            $p.Width | Should -Be 'Auto'
        }

        It 'Should produce tab-count children plus separator children between them' {
            # 3 tabs + 2 separators = 5 children
            $p = New-ElmPaginator -Tabs @('A', 'B', 'C') -ActiveTab 0
            $p.Children.Count | Should -Be 5
        }
    }

    Context 'Tabs mode - content' {
        It 'Should wrap the active tab label in brackets' {
            $p = New-ElmPaginator -Tabs @('Alpha', 'Beta') -ActiveTab 0
            $p.Children[0].Content | Should -Be '[Alpha]'
        }

        It 'Should NOT wrap inactive tab labels in brackets' {
            $p = New-ElmPaginator -Tabs @('Alpha', 'Beta') -ActiveTab 0
            $p.Children[2].Content | Should -Be 'Beta'
        }

        It 'Should use | as the separator text between tabs' {
            $p = New-ElmPaginator -Tabs @('A', 'B') -ActiveTab 0
            $p.Children[1].Content | Should -Be ' | '
        }

        It 'Should apply ActiveStyle to the active tab child' {
            $as = [PSCustomObject]@{ Foreground = 'BrightWhite' }
            $p  = New-ElmPaginator -Tabs @('A', 'B') -ActiveTab 0 -ActiveStyle $as
            $p.Children[0].Style | Should -Be $as
        }

        It 'Should apply Style to inactive tab children' {
            $s = [PSCustomObject]@{ Foreground = 'BrightBlack' }
            $p = New-ElmPaginator -Tabs @('A', 'B') -ActiveTab 0 -Style $s
            $p.Children[2].Style | Should -Be $s
        }

        It 'Should apply Style to separator children' {
            $s = [PSCustomObject]@{ Foreground = 'BrightBlack' }
            $p = New-ElmPaginator -Tabs @('A', 'B') -ActiveTab 0 -Style $s
            $p.Children[1].Style | Should -Be $s
        }
    }

    Context 'Tabs mode - ActiveTab clamping' {
        It 'Should clamp ActiveTab below 0 to 0' {
            $p = New-ElmPaginator -Tabs @('A', 'B', 'C') -ActiveTab -1
            $p.Children[0].Content | Should -Be '[A]'
        }

        It 'Should clamp ActiveTab above last index to last index' {
            $p = New-ElmPaginator -Tabs @('A', 'B', 'C') -ActiveTab 99
            $p.Children[4].Content | Should -Be '[C]'
        }
    }

    Context 'Style passthrough - Numeric' {
        It 'Should apply ActiveStyle to the numeric Text node' {
            $as = [PSCustomObject]@{ Foreground = 'BrightCyan' }
            $p  = New-ElmPaginator -CurrentPage 2 -PageCount 5 -ActiveStyle $as
            $p.Style | Should -Be $as
        }

        It 'Should fall back to Style when ActiveStyle is null' {
            $s = [PSCustomObject]@{ Foreground = 'White' }
            $p = New-ElmPaginator -CurrentPage 1 -PageCount 3 -Style $s
            $p.Style | Should -Be $s
        }
    }

    Context 'Dots mode - return value structure' {
        It 'Should return a Box node' {
            $p = New-ElmPaginator -Dots -CurrentPage 1 -PageCount 5
            $p.Type | Should -Be 'Box'
        }

        It 'Should have Direction Horizontal' {
            $p = New-ElmPaginator -Dots -CurrentPage 1 -PageCount 5
            $p.Direction | Should -Be 'Horizontal'
        }

        It 'Should have Width Auto' {
            $p = New-ElmPaginator -Dots -CurrentPage 1 -PageCount 5
            $p.Width | Should -Be 'Auto'
        }

        It 'Should have Height Auto' {
            $p = New-ElmPaginator -Dots -CurrentPage 1 -PageCount 5
            $p.Height | Should -Be 'Auto'
        }

        It 'Should produce PageCount dot children plus separator children between them' {
            # 5 dots + 4 separators = 9 children
            $p = New-ElmPaginator -Dots -CurrentPage 1 -PageCount 5
            $p.Children.Count | Should -Be 9
        }
    }

    Context 'Dots mode - content' {
        It 'Should use FilledDot for the active page' {
            $p = New-ElmPaginator -Dots -CurrentPage 3 -PageCount 5
            # child index for page 3: (3-1) * 2 = 4
            $p.Children[4].Content | Should -Be ([char]0x25CF).ToString()
        }

        It 'Should use EmptyDot for inactive pages' {
            $p = New-ElmPaginator -Dots -CurrentPage 3 -PageCount 5
            $p.Children[0].Content | Should -Be ([char]0x25CB).ToString()
        }

        It 'Should use custom FilledDot when provided' {
            $p = New-ElmPaginator -Dots -CurrentPage 2 -PageCount 3 -FilledDot '*' -EmptyDot '-'
            # child index for page 2: (2-1) * 2 = 2
            $p.Children[2].Content | Should -Be '*'
        }

        It 'Should use custom EmptyDot when provided' {
            $p = New-ElmPaginator -Dots -CurrentPage 2 -PageCount 3 -FilledDot '*' -EmptyDot '-'
            $p.Children[0].Content | Should -Be '-'
        }

        It 'Should use custom Separator between dots' {
            $p = New-ElmPaginator -Dots -CurrentPage 1 -PageCount 3 -Separator '·'
            $p.Children[1].Content | Should -Be '·'
        }

        It 'Should use a space as the default Separator' {
            $p = New-ElmPaginator -Dots -CurrentPage 1 -PageCount 3
            $p.Children[1].Content | Should -Be ' '
        }
    }

    Context 'Dots mode - clamping' {
        It 'Should clamp CurrentPage below 1 to 1 - first dot is filled' {
            $p = New-ElmPaginator -Dots -CurrentPage -5 -PageCount 5
            $p.Children[0].Content | Should -Be ([char]0x25CF).ToString()
        }

        It 'Should clamp CurrentPage above PageCount to PageCount - last dot is filled' {
            $p = New-ElmPaginator -Dots -CurrentPage 99 -PageCount 3
            # last dot child index: (3-1)*2 = 4
            $p.Children[4].Content | Should -Be ([char]0x25CF).ToString()
        }
    }

    Context 'Dots mode - styles' {
        It 'Should apply ActiveStyle to the active dot' {
            $as = [PSCustomObject]@{ Foreground = 'BrightWhite' }
            $p  = New-ElmPaginator -Dots -CurrentPage 1 -PageCount 3 -ActiveStyle $as
            $p.Children[0].Style | Should -Be $as
        }

        It 'Should apply Style to inactive dots' {
            $s = [PSCustomObject]@{ Foreground = 'BrightBlack' }
            $p = New-ElmPaginator -Dots -CurrentPage 1 -PageCount 3 -Style $s
            # child index for page 2: 2
            $p.Children[2].Style | Should -Be $s
        }

        It 'Should fall back to Style when ActiveStyle is null' {
            $s = [PSCustomObject]@{ Foreground = 'White' }
            $p = New-ElmPaginator -Dots -CurrentPage 2 -PageCount 3 -Style $s
            $p.Children[2].Style | Should -Be $s
        }

        It 'Should apply Style to separator children' {
            $s = [PSCustomObject]@{ Foreground = 'BrightBlack' }
            $p = New-ElmPaginator -Dots -CurrentPage 1 -PageCount 3 -Style $s
            $p.Children[1].Style | Should -Be $s
        }
    }
}
