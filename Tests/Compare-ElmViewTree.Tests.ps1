BeforeAll {
    . $PSScriptRoot/../Public/Style/New-ElmStyle.ps1
    . $PSScriptRoot/../Private/Rendering/Compare-ElmViewTree.ps1

    function New-MeasuredText {
        param(
            [string]$Content,
            [int]$X = 0,
            [int]$Y = 0,
            [object]$Style = $null,
            [int]$Width = -1
        )
        $w = if ($Width -ge 0) { $Width } else { $Content.Length }
        [PSCustomObject]@{
            Type          = 'Text'
            Content       = $Content
            Style         = $Style
            Width         = $w
            Height        = 1
            X             = $X
            Y             = $Y
            NaturalWidth  = $w
            NaturalHeight = 1
        }
    }

    function New-MeasuredBox {
        param(
            [object[]]$Children,
            [int]$X = 0,
            [int]$Y = 0,
            [int]$Width = 80,
            [int]$Height = 24
        )
        [PSCustomObject]@{
            Type          = 'Box'
            Direction     = 'Vertical'
            Children      = $Children
            Style         = $null
            Width         = $Width
            Height        = $Height
            X             = $X
            Y             = $Y
            NaturalWidth  = $Width
            NaturalHeight = $Height
        }
    }
}

Describe 'Compare-ElmViewTree' {
    Context 'Null old tree' {
        It 'Should return FullRedraw when old tree is null' {
            $newTree = New-MeasuredText -Content 'hello'
            $patches = Compare-ElmViewTree -OldTree $null -NewTree $newTree
            $patches | Should -HaveCount 1
            $patches[0].Type | Should -Be 'FullRedraw'
        }
    }

    Context 'Identical trees' {
        It 'Should return no patches when trees are identical' {
            $tree = New-MeasuredText -Content 'hello' -X 0 -Y 0
            $patches = Compare-ElmViewTree -OldTree $tree -NewTree $tree
            $patches | Should -HaveCount 0
        }

        It 'Should return no patches for identical box with text children' {
            $t1 = New-MeasuredText -Content 'a' -X 0 -Y 0
            $t2 = New-MeasuredText -Content 'b' -X 0 -Y 1
            $box = New-MeasuredBox -Children @($t1, $t2)
            $patches = Compare-ElmViewTree -OldTree $box -NewTree $box
            $patches | Should -HaveCount 0
        }
    }

    Context 'Content changed' {
        It 'Should return a Replace patch when content changes' {
            $oldTree = New-MeasuredText -Content 'hello' -X 0 -Y 0
            $newTree = New-MeasuredText -Content 'world' -X 0 -Y 0
            $patches = Compare-ElmViewTree -OldTree $oldTree -NewTree $newTree
            $patches | Should -HaveCount 1
            $patches[0].Type | Should -Be 'Replace'
        }

        It 'Should use new content in the Replace patch' {
            $oldTree = New-MeasuredText -Content 'old' -X 0 -Y 0
            $newTree = New-MeasuredText -Content 'new' -X 3 -Y 2
            $patches = Compare-ElmViewTree -OldTree $oldTree -NewTree $newTree
            # Position changed → FullRedraw, not Replace
            $patches[0].Type | Should -Be 'FullRedraw'
        }

        It 'Should carry X, Y from the new node into the Replace patch' {
            $oldTree = New-MeasuredText -Content 'old' -X 5 -Y 3
            $newTree = New-MeasuredText -Content 'new' -X 5 -Y 3
            $patches = Compare-ElmViewTree -OldTree $oldTree -NewTree $newTree
            $patches[0].X | Should -Be 5
            $patches[0].Y | Should -Be 3
        }

        It 'Should carry new content in the Replace patch' {
            $oldTree = New-MeasuredText -Content 'old' -X 0 -Y 0
            $newTree = New-MeasuredText -Content 'new content' -X 0 -Y 0
            $patches = Compare-ElmViewTree -OldTree $oldTree -NewTree $newTree
            $patches[0].Content | Should -Be 'new content'
        }

        It 'Should carry OldWidth from the old node in the Replace patch' {
            $oldTree = New-MeasuredText -Content 'Focus: Right' -X 0 -Y 0 -Width 12
            $newTree = New-MeasuredText -Content 'Focus: Left'  -X 0 -Y 0 -Width 11
            $patches = Compare-ElmViewTree -OldTree $oldTree -NewTree $newTree
            $patches[0].OldWidth | Should -Be 12
        }

        It 'Should carry new Width from the new node in the Replace patch' {
            $oldTree = New-MeasuredText -Content 'Focus: Right' -X 0 -Y 0 -Width 12
            $newTree = New-MeasuredText -Content 'Focus: Left'  -X 0 -Y 0 -Width 11
            $patches = Compare-ElmViewTree -OldTree $oldTree -NewTree $newTree
            $patches[0].Width | Should -Be 11
        }
    }

    Context 'Style changed' {
        It 'Should return a Replace patch when style changes' {
            $style = New-ElmStyle -Bold
            $oldTree = New-MeasuredText -Content 'hi' -X 0 -Y 0 -Style $null
            $newTree = New-MeasuredText -Content 'hi' -X 0 -Y 0 -Style $style
            $patches = Compare-ElmViewTree -OldTree $oldTree -NewTree $newTree
            $patches | Should -HaveCount 1
            $patches[0].Type | Should -Be 'Replace'
        }

        It 'Should carry new style in the Replace patch' {
            $style = New-ElmStyle -Bold
            $oldTree = New-MeasuredText -Content 'hi' -X 0 -Y 0 -Style $null
            $newTree = New-MeasuredText -Content 'hi' -X 0 -Y 0 -Style $style
            $patches = Compare-ElmViewTree -OldTree $oldTree -NewTree $newTree
            $patches[0].Style | Should -Be $style
        }
    }

    Context 'Structural change' {
        It 'Should return FullRedraw when node count changes' {
            $t1 = New-MeasuredText -Content 'a' -X 0 -Y 0
            $t2 = New-MeasuredText -Content 'b' -X 0 -Y 1
            $oldBox = New-MeasuredBox -Children @($t1)
            $newBox = New-MeasuredBox -Children @($t1, $t2)
            $patches = Compare-ElmViewTree -OldTree $oldBox -NewTree $newBox
            $patches | Should -HaveCount 1
            $patches[0].Type | Should -Be 'FullRedraw'
        }

        It 'Should return FullRedraw when node positions change' {
            $oldTree = New-MeasuredText -Content 'hi' -X 0 -Y 0
            $newTree = New-MeasuredText -Content 'hi' -X 2 -Y 1
            $patches = Compare-ElmViewTree -OldTree $oldTree -NewTree $newTree
            $patches | Should -HaveCount 1
            $patches[0].Type | Should -Be 'FullRedraw'
        }
    }

    Context 'Multiple nodes, partial change' {
        It 'Should return only the Replace patches for changed nodes' {
            $oldT1 = New-MeasuredText -Content 'unchanged' -X 0 -Y 0
            $oldT2 = New-MeasuredText -Content 'old'       -X 0 -Y 1
            $newT1 = New-MeasuredText -Content 'unchanged' -X 0 -Y 0
            $newT2 = New-MeasuredText -Content 'new'       -X 0 -Y 1
            $oldBox = New-MeasuredBox -Children @($oldT1, $oldT2)
            $newBox = New-MeasuredBox -Children @($newT1, $newT2)
            $patches = Compare-ElmViewTree -OldTree $oldBox -NewTree $newBox
            $patches | Should -HaveCount 1
            $patches[0].Content | Should -Be 'new'
        }

        It 'Should return Replace patches for all changed nodes' {
            $oldT1 = New-MeasuredText -Content 'a' -X 0 -Y 0
            $oldT2 = New-MeasuredText -Content 'b' -X 0 -Y 1
            $newT1 = New-MeasuredText -Content 'x' -X 0 -Y 0
            $newT2 = New-MeasuredText -Content 'y' -X 0 -Y 1
            $oldBox = New-MeasuredBox -Children @($oldT1, $oldT2)
            $newBox = New-MeasuredBox -Children @($newT1, $newT2)
            $patches = Compare-ElmViewTree -OldTree $oldBox -NewTree $newBox
            $patches | Should -HaveCount 2
        }
    }
}
