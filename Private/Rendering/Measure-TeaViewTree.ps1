function Measure-TeaViewTree {
    <#
    .SYNOPSIS
        Performs two-pass flexbox layout on a view tree, assigning X, Y, Width, Height.

    .DESCRIPTION
        Pass 1 (bottom-up): computes NaturalWidth/NaturalHeight for each node based on
        content, padding, and border settings. Fill children are skipped during parent
        natural-size computation.

        Pass 2 (top-down): resolves final Width/Height using the available space from
        the parent, then assigns absolute X/Y coordinates. Fill nodes receive an equal
        share of remaining space; % nodes are resolved against the parent's resolved width.

    .PARAMETER Root
        The root view node of the tree to measure.

    .PARAMETER TermWidth
        Available terminal width in columns.

    .PARAMETER TermHeight
        Available terminal height in rows.

    .OUTPUTS
        PSCustomObject - a new tree with the same structure as the input but with
        X, Y, Width, Height, NaturalWidth, and NaturalHeight fields on every node.

    .EXAMPLE
        $tree     = New-TeaBox -Children @(New-TeaText -Content 'Hello') -Width 'Fill'
        $measured = Measure-TeaViewTree -Root $tree -TermWidth 80 -TermHeight 24

    .NOTES
        Does not mutate the input tree; returns a new copy.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Root,

        [Parameter(Mandatory)]
        [int]$TermWidth,

        [Parameter(Mandatory)]
        [int]$TermHeight
    )

    $withNatural = Invoke-TeaPass1 -Node $Root
    $measured    = Invoke-TeaPass2 -Node $withNatural -AvailableWidth $TermWidth -AvailableHeight $TermHeight -X 0 -Y 0
    return $measured
}


