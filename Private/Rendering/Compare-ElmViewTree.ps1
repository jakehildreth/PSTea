function Compare-ElmViewTree {
    <#
    .SYNOPSIS
        Diffs two measured view trees and returns a list of patches.

    .DESCRIPTION
        Compares an old and new measured view tree (produced by Measure-ElmViewTree)
        and returns an array of patch objects for use with ConvertTo-AnsiPatch.

        Patch types:
        - FullRedraw: returned as a single-item array when the old tree is $null or when
          the layout has changed (different number of leaf nodes or any position shifted).
        - Replace: returned for each Text leaf node whose Content or Style has changed.
        - Empty array: returned when both trees are structurally identical with identical
          content and styles.

        Compare-ElmViewTree does not emit Clear patches. The caller should treat
        FullRedraw patches by invoking ConvertTo-AnsiOutput for a full re-render.

    .PARAMETER OldTree
        The previously measured view tree. Pass $null on the first render.

    .PARAMETER NewTree
        The newly measured view tree to compare against the old tree.

    .OUTPUTS
        [object[]] — An array of patch PSCustomObjects. May be empty, contain only a
        single FullRedraw, or contain one or more Replace patches.

    .EXAMPLE
        $measured = Measure-ElmViewTree -Root $view -TermWidth 80 -TermHeight 24
        $patches  = Compare-ElmViewTree -OldTree $prevMeasured -NewTree $measured
        if ($patches | Where-Object { $_.Type -eq 'FullRedraw' }) {
            [Console]::Out.Write((ConvertTo-AnsiOutput -MeasuredRoot $measured))
        } else {
            [Console]::Out.Write((ConvertTo-AnsiPatch -Patches $patches))
        }

    .NOTES
        Structural matching is positional (by traversal index). If the leaf count or
        any leaf position differs between old and new, FullRedraw is returned immediately.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [object]$OldTree,

        [Parameter(Mandatory)]
        [object]$NewTree
    )

    if ($null -eq $OldTree) {
        return @([PSCustomObject]@{ Type = 'FullRedraw' })
    }

    $oldLeaves = Get-TextLeaves -Node $OldTree
    $newLeaves = Get-TextLeaves -Node $NewTree

    if ($oldLeaves.Count -ne $newLeaves.Count) {
        return @([PSCustomObject]@{ Type = 'FullRedraw' })
    }

    $patches = [System.Collections.Generic.List[object]]::new()

    for ($i = 0; $i -lt $newLeaves.Count; $i++) {
        $oldLeaf = $oldLeaves[$i]
        $newLeaf = $newLeaves[$i]

        if ($oldLeaf.X -ne $newLeaf.X -or $oldLeaf.Y -ne $newLeaf.Y) {
            return @([PSCustomObject]@{ Type = 'FullRedraw' })
        }

        $oldStyleJson = $oldLeaf.Style | ConvertTo-Json -Compress -Depth 2
        $newStyleJson = $newLeaf.Style | ConvertTo-Json -Compress -Depth 2

        if ($oldLeaf.Content -ne $newLeaf.Content -or $oldStyleJson -ne $newStyleJson) {
            $patches.Add([PSCustomObject]@{
                Type    = 'Replace'
                X       = $newLeaf.X
                Y       = $newLeaf.Y
                Content = $newLeaf.Content
                Style   = $newLeaf.Style
                Width   = $newLeaf.Width
            })
        }
    }

    return $patches.ToArray()
}

function Get-TextLeaves {
    param(
        [Parameter(Mandatory)]
        [object]$Node
    )

    $leaves = [System.Collections.Generic.List[object]]::new()
    $stack  = [System.Collections.Generic.Stack[object]]::new()
    $stack.Push($Node)

    while ($stack.Count -gt 0) {
        $current = $stack.Pop()
        if ($current.Type -eq 'Text') {
            $leaves.Add($current)
        } elseif ($current.PSObject.Properties['Children'] -and $null -ne $current.Children) {
            for ($i = $current.Children.Count - 1; $i -ge 0; $i--) {
                $stack.Push($current.Children[$i])
            }
        }
    }

    return $leaves.ToArray()
}
