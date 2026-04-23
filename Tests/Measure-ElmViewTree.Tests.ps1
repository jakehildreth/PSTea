BeforeAll {
    . $PSScriptRoot/../Public/View/New-ElmText.ps1
    . $PSScriptRoot/../Public/View/New-ElmBox.ps1
    . $PSScriptRoot/../Public/View/New-ElmRow.ps1
    . $PSScriptRoot/../Public/View/New-ElmComponent.ps1
    . $PSScriptRoot/../Public/Style/New-ElmStyle.ps1
    . $PSScriptRoot/../Private/Rendering/Measure-ElmViewTree.ps1
}

Describe 'Measure-ElmViewTree' {
    Context 'Single Text node' {
        It 'Should measure Width = content.Length for Auto text' {
            $text = New-ElmText -Content 'hello'
            $m = Measure-ElmViewTree -Root $text -TermWidth 80 -TermHeight 24
            $m.Width | Should -Be 5
        }

        It 'Should set X = 0 for root text node' {
            $text = New-ElmText -Content 'hello'
            $m = Measure-ElmViewTree -Root $text -TermWidth 80 -TermHeight 24
            $m.X | Should -Be 0
        }

        It 'Should set Y = 0 for root text node' {
            $text = New-ElmText -Content 'hello'
            $m = Measure-ElmViewTree -Root $text -TermWidth 80 -TermHeight 24
            $m.Y | Should -Be 0
        }

        It 'Should set Height = 1 for a single-line text node' {
            $text = New-ElmText -Content 'hello'
            $m = Measure-ElmViewTree -Root $text -TermWidth 80 -TermHeight 24
            $m.Height | Should -Be 1
        }
    }

    Context 'Text node with padding' {
        It 'Should include PaddingLeft in measured Width' {
            $style = New-ElmStyle -Padding 0, 2
            $text = New-ElmText -Content 'hi' -Style $style
            $m = Measure-ElmViewTree -Root $text -TermWidth 80 -TermHeight 24
            # PaddingLeft=2, PaddingRight=2 → Width = 2 + 2 + 2 = 6
            $m.Width | Should -Be 6
        }

        It 'Should include only PaddingLeft when asymmetric' {
            $style = New-ElmStyle -Padding 0, 0, 0, 3
            $text = New-ElmText -Content 'hi' -Style $style
            $m = Measure-ElmViewTree -Root $text -TermWidth 80 -TermHeight 24
            # PaddingLeft=3, PaddingRight=0 → Width = 2 + 3 + 0 = 5
            $m.Width | Should -Be 5
        }
    }

    Context 'Two Text nodes in a Vertical Box' {
        It 'Should place second child at Y = 1' {
            $t1 = New-ElmText -Content 'a'
            $t2 = New-ElmText -Content 'b'
            $box = New-ElmBox -Children @($t1, $t2)
            $m = Measure-ElmViewTree -Root $box -TermWidth 80 -TermHeight 24
            $m.Children[1].Y | Should -Be 1
        }

        It 'Should place first child at Y = 0' {
            $t1 = New-ElmText -Content 'a'
            $t2 = New-ElmText -Content 'b'
            $box = New-ElmBox -Children @($t1, $t2)
            $m = Measure-ElmViewTree -Root $box -TermWidth 80 -TermHeight 24
            $m.Children[0].Y | Should -Be 0
        }
    }

    Context 'Fill child node' {
        It 'Should give a root Fill Box the full TermWidth' {
            $fill = New-ElmBox -Children @() -Width 'Fill'
            $m = Measure-ElmViewTree -Root $fill -TermWidth 80 -TermHeight 24
            $m.Width | Should -Be 80
        }

        It 'Should give a Fill child in a Horizontal row the full remaining width' {
            $fill = New-ElmBox -Children @() -Width 'Fill'
            $root = New-ElmRow -Children @($fill) -Width 'Fill'
            $m = Measure-ElmViewTree -Root $root -TermWidth 80 -TermHeight 24
            $m.Children[0].Width | Should -Be 80
        }

        It 'Should split width equally between two Fill children' {
            $f1 = New-ElmBox -Children @() -Width 'Fill'
            $f2 = New-ElmBox -Children @() -Width 'Fill'
            $root = New-ElmRow -Children @($f1, $f2) -Width 'Fill'
            $m = Measure-ElmViewTree -Root $root -TermWidth 80 -TermHeight 24
            $m.Children[0].Width | Should -Be 40
            $m.Children[1].Width | Should -Be 40
        }
    }

    Context 'Percentage width child' {
        It 'Should resolve 50% to floor(parentWidth * 0.5)' {
            $child = New-ElmBox -Children @() -Width '50%'
            $root = New-ElmRow -Children @($child) -Width 'Fill'
            $m = Measure-ElmViewTree -Root $root -TermWidth 80 -TermHeight 24
            $m.Children[0].Width | Should -Be 40
        }

        It 'Should floor the result for odd percentage' {
            $child = New-ElmBox -Children @() -Width '33%'
            $root = New-ElmRow -Children @($child) -Width 'Fill'
            $m = Measure-ElmViewTree -Root $root -TermWidth 80 -TermHeight 24
            $m.Children[0].Width | Should -Be 26
        }
    }

    Context 'Nested boxes with absolute coordinates' {
        It 'Should compute correct X for a child in a second column' {
            $inner1 = New-ElmText -Content 'a'
            $inner2 = New-ElmText -Content 'b'
            $left  = New-ElmBox -Children @($inner1) -Width 40
            $right = New-ElmBox -Children @($inner2) -Width 40
            $root  = New-ElmRow -Children @($left, $right) -Width 80
            $m = Measure-ElmViewTree -Root $root -TermWidth 80 -TermHeight 24
            $m.Children[1].Children[0].X | Should -Be 40
        }

        It 'Should compute correct Y for inner child in stacked layout' {
            $top    = New-ElmText -Content 'top'
            $bottom = New-ElmText -Content 'bottom'
            $inner  = New-ElmBox -Children @($top, $bottom)
            $root   = New-ElmBox -Children @($inner)
            $m = Measure-ElmViewTree -Root $root -TermWidth 80 -TermHeight 24
            $m.Children[0].Children[1].Y | Should -Be 1
        }
    }

    Context 'Component node' {
        It 'Should expand a Component node into its ViewFn output' {
            $model  = [PSCustomObject]@{ Label = 'hi' }
            $viewFn = { param($m) New-ElmText -Content $m.Label }
            $comp   = New-ElmComponent -ComponentId 'label' -SubModel $model -ViewFn $viewFn
            $result = Measure-ElmViewTree -Root $comp -TermWidth 80 -TermHeight 24
            $result.Type    | Should -Be 'Text'
            $result.Content | Should -Be 'hi'
        }

        It 'Should measure the expanded subtree correctly' {
            $model  = [PSCustomObject]@{ Label = 'hello' }
            $viewFn = { param($m) New-ElmText -Content $m.Label }
            $comp   = New-ElmComponent -ComponentId 'x' -SubModel $model -ViewFn $viewFn
            $result = Measure-ElmViewTree -Root $comp -TermWidth 80 -TermHeight 24
            $result.Width | Should -Be 5
            $result.X     | Should -Be 0
            $result.Y     | Should -Be 0
        }

        It 'Should place a Component inside a Box at the correct Y position' {
            $model  = [PSCustomObject]@{ Label = 'world' }
            $viewFn = { param($m) New-ElmText -Content $m.Label }
            $comp   = New-ElmComponent -ComponentId 'comp' -SubModel $model -ViewFn $viewFn
            $first  = New-ElmText -Content 'first'
            $box    = New-ElmBox -Children @($first, $comp)
            $result = Measure-ElmViewTree -Root $box -TermWidth 80 -TermHeight 24
            $result.Children[1].Y | Should -Be 1
        }

        It 'Should expand a nested Component (component inside component ViewFn)' {
            $innerModel  = [PSCustomObject]@{ Value = 'inner' }
            $innerViewFn = { param($m) New-ElmText -Content $m.Value }
            $outerModel  = [PSCustomObject]@{ Sub = $innerModel; InnerViewFn = $innerViewFn }
            $outerViewFn = {
                param($m)
                New-ElmComponent -ComponentId 'inner' -SubModel $m.Sub -ViewFn $m.InnerViewFn
            }
            $comp   = New-ElmComponent -ComponentId 'outer' -SubModel $outerModel -ViewFn $outerViewFn
            $result = Measure-ElmViewTree -Root $comp -TermWidth 80 -TermHeight 24
            $result.Type    | Should -Be 'Text'
            $result.Content | Should -Be 'inner'
        }

        It 'Should not produce any Component-type nodes in the measured output' {
            $model  = [PSCustomObject]@{ Label = 'test' }
            $viewFn = { param($m) New-ElmText -Content $m.Label }
            $comp   = New-ElmComponent -ComponentId 'x' -SubModel $model -ViewFn $viewFn
            $box    = New-ElmBox -Children @($comp)
            $result = Measure-ElmViewTree -Root $box -TermWidth 80 -TermHeight 24
            $result.Type                 | Should -Be 'Box'
            $result.Children[0].Type     | Should -Be 'Text'
        }
    }
}
