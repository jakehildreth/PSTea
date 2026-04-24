BeforeAll {
    . $PSScriptRoot/../Public/View/New-ElmViewport.ps1
}

Describe 'New-ElmViewport' -Tag 'Unit', 'P9' {

    Context 'Return value structure' {
        It 'Should return a Box node' {
            $vp = New-ElmViewport -Lines @('a', 'b', 'c') -MaxVisible 5
            $vp.Type | Should -Be 'Box'
        }

        It 'Should have Direction Vertical' {
            $vp = New-ElmViewport -Lines @('a', 'b', 'c') -MaxVisible 5
            $vp.Direction | Should -Be 'Vertical'
        }

        It 'Should have a Children array' {
            $vp = New-ElmViewport -Lines @('a', 'b', 'c') -MaxVisible 5
            $vp.Children | Should -Not -BeNull
        }
    }

    Context 'Basic windowing' {
        It 'Should show all lines when count <= MaxVisible' {
            $lines = @('Line 1', 'Line 2', 'Line 3')
            $vp    = New-ElmViewport -Lines $lines -MaxVisible 10
            $vp.Children.Count | Should -Be 3
        }

        It 'Should show MaxVisible lines when count > MaxVisible' {
            $lines = 1..20 | ForEach-Object { "Line $_" }
            $vp    = New-ElmViewport -Lines $lines -MaxVisible 5
            $vp.Children.Count | Should -Be 5
        }

        It 'Should show lines starting from ScrollOffset' {
            $lines = @('A', 'B', 'C', 'D', 'E')
            $vp    = New-ElmViewport -Lines $lines -ScrollOffset 2 -MaxVisible 3
            $vp.Children[0].Content | Should -Be 'C'
            $vp.Children[1].Content | Should -Be 'D'
            $vp.Children[2].Content | Should -Be 'E'
        }

        It 'Should show correct content at offset 0' {
            $lines = @('First', 'Second', 'Third')
            $vp    = New-ElmViewport -Lines $lines -ScrollOffset 0 -MaxVisible 2
            $vp.Children[0].Content | Should -Be 'First'
            $vp.Children[1].Content | Should -Be 'Second'
        }
    }

    Context 'ScrollOffset clamping' {
        It 'Should clamp ScrollOffset below 0 to 0' {
            $lines = @('A', 'B', 'C')
            $vp    = New-ElmViewport -Lines $lines -ScrollOffset -5 -MaxVisible 3
            $vp.Children[0].Content | Should -Be 'A'
        }

        It 'Should clamp ScrollOffset so window does not exceed end of lines' {
            $lines = @('A', 'B', 'C')
            $vp    = New-ElmViewport -Lines $lines -ScrollOffset 100 -MaxVisible 3
            # All 3 lines should be visible
            $vp.Children.Count | Should -Be 3
            $vp.Children[-1].Content | Should -Be 'C'
        }
    }

    Context 'Empty lines' {
        It 'Should return a single-child Box when Lines is empty' {
            $vp = New-ElmViewport -Lines @() -MaxVisible 5
            $vp.Type           | Should -Be 'Box'
            $vp.Children.Count | Should -Be 1
        }
    }

    Context 'Style passthrough' {
        It 'Should apply Style to each visible line' {
            $style = [PSCustomObject]@{ Foreground = 'BrightBlack' }
            $lines = @('A', 'B', 'C')
            $vp    = New-ElmViewport -Lines $lines -MaxVisible 3 -Style $style
            foreach ($child in $vp.Children) {
                $child.Style | Should -Be $style
            }
        }

        It 'Should have null Style on children when Style omitted' {
            $lines = @('A', 'B')
            $vp    = New-ElmViewport -Lines $lines -MaxVisible 2
            $vp.Children[0].Style | Should -BeNullOrEmpty
        }
    }
}
