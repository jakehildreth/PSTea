BeforeAll {
    . $PSScriptRoot/../Public/View/New-TeaTable.ps1
}

Describe 'New-TeaTable' -Tag 'Unit', 'P10' {

    Context 'Return value structure' {
        It 'Should return a Box node' {
            $t = New-TeaTable -Rows @(@('A', 'B'))
            $t.Type | Should -Be 'Box'
        }

        It 'Should have Direction Vertical' {
            $t = New-TeaTable -Rows @(@('A', 'B'))
            $t.Direction | Should -Be 'Vertical'
        }

        It 'Should have Width Auto' {
            $t = New-TeaTable -Rows @(@('A', 'B'))
            $t.Width | Should -Be 'Auto'
        }

        It 'Should have Height Auto' {
            $t = New-TeaTable -Rows @(@('A', 'B'))
            $t.Height | Should -Be 'Auto'
        }
    }

    Context 'Empty rows' {
        It 'Should return a Box with a single empty Text child when Rows is empty' {
            $t = New-TeaTable -Rows @()
            $t.Children.Count | Should -Be 1
        }

        It 'Should return empty content child when Rows is empty' {
            $t = New-TeaTable -Rows @()
            $t.Children[0].Content | Should -Be ''
        }
    }

    Context 'Rows without headers' {
        It 'Should render one Text child per row' {
            $t = New-TeaTable -Rows @(@('A', '1'), @('B', '2'))
            $t.Children.Count | Should -Be 2
        }

        It 'Should pad cells to auto-calculated column width' {
            # col0 max = max(len(Alice)=5, len(Bob)=3) = 5
            # col1 max = max(len(30)=2, len(25)=2) = 2
            $t = New-TeaTable -Rows @(@('Alice', '30'), @('Bob', '25'))
            $t.Children[0].Content | Should -Be 'Alice | 30'
            $t.Children[1].Content | Should -Be 'Bob   | 25'
        }

        It 'Should pad short rows with empty cells' {
            $t = New-TeaTable -Rows @(@('A', 'B'), @('X'))
            # Row 1 has only 1 cell; col1 gets empty string padded to col1 width (1)
            # 'X'.PadRight(1) = 'X'; ''.PadRight(1) = ' '; joined: 'X' + ' | ' + ' ' = 'X |  '
            $t.Children[1].Content | Should -Be 'X |  '
        }
    }

    Context 'Rows with headers' {
        It 'Should render header row + separator row + data rows' {
            $row = @('Alice', '30')
            $t   = New-TeaTable -Headers @('Name', 'Age') -Rows @(,$row)
            $t.Children.Count | Should -Be 3
        }

        It 'Should include header labels in header row content' {
            $t = New-TeaTable -Headers @('Name', 'Age') -Rows @(@('Alice', '30'))
            $t.Children[0].Content | Should -Match 'Name'
            $t.Children[0].Content | Should -Match 'Age'
        }

        It 'Should render separator row starting with dashes' {
            $t = New-TeaTable -Headers @('Name', 'Age') -Rows @(@('Alice', '30'))
            $t.Children[1].Content | Should -Match '^-'
        }

        It 'Should include a + in the separator row between columns' {
            $t = New-TeaTable -Headers @('Name', 'Age') -Rows @(@('Alice', '30'))
            $t.Children[1].Content | Should -Match '\+'
        }

        It 'Should apply HeaderStyle to the header row' {
            $hs = [PSCustomObject]@{ Foreground = 'BrightCyan' }
            $t  = New-TeaTable -Headers @('X') -Rows @(@('A')) -HeaderStyle $hs
            $t.Children[0].Style | Should -Be $hs
        }

        It 'Should apply HeaderStyle to the separator row' {
            $hs = [PSCustomObject]@{ Foreground = 'BrightCyan' }
            $t  = New-TeaTable -Headers @('X') -Rows @(@('A')) -HeaderStyle $hs
            $t.Children[1].Style | Should -Be $hs
        }
    }

    Context 'Column width calculation' {
        It 'Should use header width when it exceeds all cell widths' {
            # Header 'Column' (6) > all cells 'A','B' (1 each)
            $t = New-TeaTable -Headers @('Column') -Rows @(@('A'), @('B'))
            $t.Children[0].Content | Should -Be 'Column'
            $t.Children[2].Content | Should -Be 'A     '
        }

        It 'Should use cell width when it exceeds the header width' {
            $t = New-TeaTable -Headers @('N') -Rows @(@('Alice'))
            # col0 width = max(1, 5) = 5; header 'N' padded to 5
            $t.Children[0].Content | Should -Be 'N    '
        }

        It 'Should override with explicit ColumnWidths when count matches' {
            $row = @('A', 'B')
            $t   = New-TeaTable -Rows @(,$row) -ColumnWidths @(10, 5)
            # 'A'.PadRight(10)='A         ', 'B'.PadRight(5)='B    '; joined: 'A          | B    '
            $t.Children[0].Content | Should -Be 'A          | B    '
        }
    }

    Context 'SelectedRow' {
        It 'Should apply default bold SelectedStyle to the selected row' {
            $t = New-TeaTable -Rows @(@('A'), @('B')) -SelectedRow 0
            $t.Children[0].Style.Bold | Should -Be $true
        }

        It 'Should apply explicit SelectedStyle to the selected row' {
            $ss = [PSCustomObject]@{ Foreground = 'BrightYellow' }
            $t  = New-TeaTable -Rows @(@('A'), @('B')) -SelectedRow 1 -SelectedStyle $ss
            $t.Children[1].Style | Should -Be $ss
        }

        It 'Should apply base Style to unselected rows' {
            $s  = [PSCustomObject]@{ Foreground = 'White' }
            $ss = [PSCustomObject]@{ Foreground = 'BrightYellow' }
            $t  = New-TeaTable -Rows @(@('A'), @('B')) -SelectedRow 0 -Style $s -SelectedStyle $ss
            $t.Children[1].Style | Should -Be $s
        }

        It 'Should apply base Style to all rows when SelectedRow is -1' {
            $s = [PSCustomObject]@{ Foreground = 'White' }
            $t = New-TeaTable -Rows @(@('A'), @('B')) -SelectedRow -1 -Style $s
            $t.Children[0].Style | Should -Be $s
            $t.Children[1].Style | Should -Be $s
        }

        It 'Should have correct row count when SelectedRow is set with headers' {
            $t = New-TeaTable -Headers @('H') -Rows @(@('A'), @('B')) -SelectedRow 1
            # header + sep + 2 data rows = 4 children
            $t.Children.Count | Should -Be 4
        }
    }
}
