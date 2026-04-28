function Invoke-TeaPass1 {
    <#
    .SYNOPSIS
        Pass 1 of the two-pass layout algorithm: compute natural sizes bottom-up.

    .DESCRIPTION
        Recursively traverses the view tree and annotates each node with NaturalWidth,
        NaturalHeight, and placeholder X/Y coordinates. Component nodes are expanded
        inline by calling their ViewFn. Does not assign final positions or resolve Fill
        dimensions - that is deferred to Invoke-TeaPass2.

    .PARAMETER Node
        The view tree node to measure. Must be a Text, Box, or Component PSCustomObject.

    .OUTPUTS
        PSCustomObject - the annotated node tree with NaturalWidth and NaturalHeight.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Node
    )

    $style         = $Node.Style
    $paddingLeft   = if ($null -ne $style) { [int]$style.PaddingLeft } else { 0 }
    $paddingRight  = if ($null -ne $style) { [int]$style.PaddingRight } else { 0 }
    $paddingTop    = if ($null -ne $style) { [int]$style.PaddingTop } else { 0 }
    $paddingBottom = if ($null -ne $style) { [int]$style.PaddingBottom } else { 0 }
    $hasBorder     = ($null -ne $style) -and ($style.Border -ne 'None') -and ($null -ne $style.Border)
    $borderExtra   = if ($hasBorder) { 2 } else { 0 }

    if ($Node.Type -eq 'Text') {
        $naturalWidth  = $Node.Content.Length + $paddingLeft + $paddingRight + $borderExtra
        $naturalHeight = 1 + $paddingTop + $paddingBottom + $borderExtra

        return [PSCustomObject]@{
            Type          = 'Text'
            Content       = $Node.Content
            Style         = $Node.Style
            Width         = $Node.Width
            Height        = $Node.Height
            NaturalWidth  = $naturalWidth
            NaturalHeight = $naturalHeight
            X             = 0
            Y             = 0
        }
    }

    if ($Node.Type -eq 'Component') {
        # Expand the component by calling its ViewFn with its SubModel.
        # The resulting subtree is measured transparently - no Component nodes
        # appear in the measured output.
        $expanded = & $Node.ViewFn $Node.SubModel
        return Invoke-TeaPass1 -Node $expanded
    }

    # Box node - recurse into all children first
    $measuredChildren = [System.Collections.ArrayList]::new()
    foreach ($child in $Node.Children) {
        [void]$measuredChildren.Add((Invoke-TeaPass1 -Node $child))
    }

    # Compute parent natural size from non-Fill children only
    $nonFill = @($measuredChildren | Where-Object { $_.Width -ne 'Fill' })

    if ($Node.Direction -eq 'Vertical') {
        $naturalWidth  = if ($nonFill.Count -gt 0) {
            ($nonFill | Measure-Object -Property NaturalWidth -Maximum).Maximum
        } else { 0 }
        $naturalHeight = if ($measuredChildren.Count -gt 0) {
            ($measuredChildren | Measure-Object -Property NaturalHeight -Sum).Sum
        } else { 0 }
    } else {
        # Horizontal
        $naturalWidth  = if ($nonFill.Count -gt 0) {
            ($nonFill | Measure-Object -Property NaturalWidth -Sum).Sum
        } else { 0 }
        $naturalHeight = if ($measuredChildren.Count -gt 0) {
            ($measuredChildren | Measure-Object -Property NaturalHeight -Maximum).Maximum
        } else { 0 }
    }

    return [PSCustomObject]@{
        Type          = 'Box'
        Direction     = $Node.Direction
        Children      = $measuredChildren.ToArray()
        Style         = $Node.Style
        Width         = $Node.Width
        Height        = $Node.Height
        NaturalWidth  = $naturalWidth
        NaturalHeight = $naturalHeight
        X             = 0
        Y             = 0
    }
}
