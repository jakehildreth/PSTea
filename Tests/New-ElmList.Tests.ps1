BeforeAll {
    . $PSScriptRoot/../Public/View/New-ElmList.ps1
}

Describe 'New-ElmList' -Tag 'Unit', 'P9' {

    Context 'Return value structure' {
        It 'Should return a Box node' {
            $list = New-ElmList -Items @('A', 'B', 'C') -SelectedIndex 0
            $list.Type | Should -Be 'Box'
        }

        It 'Should have Direction Vertical' {
            $list = New-ElmList -Items @('A', 'B', 'C') -SelectedIndex 0
            $list.Direction | Should -Be 'Vertical'
        }

        It 'Should have a Children array' {
            $list = New-ElmList -Items @('A', 'B', 'C') -SelectedIndex 0
            $list.Children | Should -Not -BeNull
        }
    }

    Context 'Basic rendering' {
        It 'Should render all items when count <= MaxVisible' {
            $list = New-ElmList -Items @('X', 'Y', 'Z') -SelectedIndex 0 -MaxVisible 10
            $list.Children.Count | Should -Be 3
        }

        It 'Should prefix selected item with > ' {
            $list = New-ElmList -Items @('Alpha', 'Beta') -SelectedIndex 1
            $list.Children[1].Content | Should -Be '> Beta'
        }

        It 'Should prefix unselected items with spaces' {
            $list = New-ElmList -Items @('Alpha', 'Beta') -SelectedIndex 1
            $list.Children[0].Content | Should -Be '  Alpha'
        }

        It 'Should apply SelectedStyle to selected item' {
            $selStyle = [PSCustomObject]@{ Foreground = 'BrightYellow' }
            $list     = New-ElmList -Items @('A', 'B') -SelectedIndex 0 -SelectedStyle $selStyle
            $list.Children[0].Style | Should -Be $selStyle
        }

        It 'Should apply base Style to unselected items' {
            $baseStyle = [PSCustomObject]@{ Foreground = 'White' }
            $list      = New-ElmList -Items @('A', 'B') -SelectedIndex 0 -Style $baseStyle
            $list.Children[1].Style | Should -Be $baseStyle
        }
    }

    Context 'Scrolling behavior' {
        It 'Should show only MaxVisible items when list is longer' {
            $items = 1..20 | ForEach-Object { "Item $_" }
            $list  = New-ElmList -Items $items -SelectedIndex 0 -MaxVisible 5
            $list.Children.Count | Should -Be 5
        }

        It 'Should scroll window to keep SelectedIndex visible when near end' {
            $items = 1..20 | ForEach-Object { "Item $_" }
            $list  = New-ElmList -Items $items -SelectedIndex 19 -MaxVisible 5
            # Last 5 items should be visible: 15..19
            $list.Children.Count | Should -Be 5
            $list.Children[4].Content | Should -Be '> Item 20'
        }

        It 'Should scroll window when SelectedIndex is in middle' {
            $items = 1..20 | ForEach-Object { "Item $_" }
            $list  = New-ElmList -Items $items -SelectedIndex 10 -MaxVisible 5
            $list.Children.Count | Should -Be 5
        }
    }

    Context 'SelectedIndex clamping' {
        It 'Should clamp SelectedIndex below 0 to 0' {
            $list = New-ElmList -Items @('A', 'B', 'C') -SelectedIndex -1
            $list.Children[0].Content | Should -Be '> A'
        }

        It 'Should clamp SelectedIndex above max to last item' {
            $list = New-ElmList -Items @('A', 'B', 'C') -SelectedIndex 99
            $list.Children[-1].Content | Should -Be '> C'
        }
    }

    Context 'Empty items' {
        It 'Should return a single-child Box when Items is empty' {
            $list = New-ElmList -Items @() -SelectedIndex 0
            $list.Type             | Should -Be 'Box'
            $list.Children.Count   | Should -Be 1
        }
    }

    Context 'Custom prefix' {
        It 'Should use custom Prefix for selected item' {
            $list = New-ElmList -Items @('A', 'B') -SelectedIndex 0 -Prefix '* ' -UnselectedPrefix '  '
            $list.Children[0].Content | Should -Be '* A'
        }
    }
}
