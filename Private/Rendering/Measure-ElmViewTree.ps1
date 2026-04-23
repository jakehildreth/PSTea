function Resolve-ElmDimension {
    param(
        [object]$Value,
        [int]$Available,
        [int]$Natural
    )

    if ($Value -eq 'Auto') { return $Natural }
    if ($Value -eq 'Fill') { return $Available }
    if ($Value -is [int])  { return $Value }
    if ($Value -match '^(\d+)%$') {
        return [int][Math]::Floor($Available * [int]$Matches[1] / 100)
    }
    return $Natural
}

function Invoke-ElmPass1 {
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

    # Box node — recurse into all children first
    $measuredChildren = [System.Collections.ArrayList]::new()
    foreach ($child in $Node.Children) {
        [void]$measuredChildren.Add((Invoke-ElmPass1 -Node $child))
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

function Invoke-ElmPass2 {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Node,
        [Parameter(Mandatory)]
        [int]$AvailableWidth,
        [Parameter(Mandatory)]
        [int]$AvailableHeight,
        [Parameter(Mandatory)]
        [int]$X,
        [Parameter(Mandatory)]
        [int]$Y
    )

    $resolvedWidth  = Resolve-ElmDimension -Value $Node.Width  -Available $AvailableWidth  -Natural $Node.NaturalWidth
    $resolvedHeight = Resolve-ElmDimension -Value $Node.Height -Available $AvailableHeight -Natural $Node.NaturalHeight

    if ($Node.Type -eq 'Text') {
        return [PSCustomObject]@{
            Type          = 'Text'
            Content       = $Node.Content
            Style         = $Node.Style
            Width         = $resolvedWidth
            Height        = $resolvedHeight
            NaturalWidth  = $Node.NaturalWidth
            NaturalHeight = $Node.NaturalHeight
            X             = $X
            Y             = $Y
        }
    }

    # Box node — distribute space to children
    $resolvedChildren = [System.Collections.ArrayList]::new()

    if ($Node.Direction -eq 'Horizontal') {
        # Pre-compute each non-Fill child's resolved width (against parent) for fill distribution.
        # We store the resolved value only for accounting; non-Fill children are still called with
        # the parent's resolvedWidth as AvailableWidth so they resolve % against the parent.
        $childResolvedW = @{}
        $fixedTotal     = 0
        $fillCount      = 0

        for ($i = 0; $i -lt $Node.Children.Count; $i++) {
            $child = $Node.Children[$i]
            if ($child.Width -eq 'Fill') {
                $fillCount++
                $childResolvedW[$i] = $null
            } else {
                $w = Resolve-ElmDimension -Value $child.Width -Available $resolvedWidth -Natural $child.NaturalWidth
                $childResolvedW[$i] = $w
                $fixedTotal += $w
            }
        }

        $remainingW = [Math]::Max(0, $resolvedWidth - $fixedTotal)
        $fillW      = if ($fillCount -gt 0) { [int][Math]::Floor($remainingW / $fillCount) } else { 0 }
        $lastFillW  = if ($fillCount -gt 0) { $remainingW - ($fillW * ($fillCount - 1)) } else { 0 }

        $cursorX   = $X
        $fillIndex = 0
        for ($i = 0; $i -lt $Node.Children.Count; $i++) {
            $child = $Node.Children[$i]
            if ($null -eq $childResolvedW[$i]) {
                # Fill child: pass the computed fill slice as AvailableWidth
                $fillIndex++
                $avail = if ($fillIndex -eq $fillCount) { $lastFillW } else { $fillW }
            } else {
                # Non-fill child: pass parent resolvedWidth so % resolves correctly inside
                $avail = $resolvedWidth
            }
            $rc = Invoke-ElmPass2 -Node $child -AvailableWidth $avail -AvailableHeight $resolvedHeight -X $cursorX -Y $Y
            [void]$resolvedChildren.Add($rc)
            $cursorX += $rc.Width
        }
    } else {
        # Vertical — same pattern, distributing height
        $childResolvedH = @{}
        $fixedTotal     = 0
        $fillCount      = 0

        for ($i = 0; $i -lt $Node.Children.Count; $i++) {
            $child = $Node.Children[$i]
            if ($child.Height -eq 'Fill') {
                $fillCount++
                $childResolvedH[$i] = $null
            } else {
                $h = Resolve-ElmDimension -Value $child.Height -Available $resolvedHeight -Natural $child.NaturalHeight
                $childResolvedH[$i] = $h
                $fixedTotal += $h
            }
        }

        $remainingH = [Math]::Max(0, $resolvedHeight - $fixedTotal)
        $fillH      = if ($fillCount -gt 0) { [int][Math]::Floor($remainingH / $fillCount) } else { 0 }
        $lastFillH  = if ($fillCount -gt 0) { $remainingH - ($fillH * ($fillCount - 1)) } else { 0 }

        $cursorY   = $Y
        $fillIndex = 0
        for ($i = 0; $i -lt $Node.Children.Count; $i++) {
            $child = $Node.Children[$i]
            if ($null -eq $childResolvedH[$i]) {
                $fillIndex++
                $avail = if ($fillIndex -eq $fillCount) { $lastFillH } else { $fillH }
            } else {
                $avail = $resolvedHeight
            }
            $rc = Invoke-ElmPass2 -Node $child -AvailableWidth $resolvedWidth -AvailableHeight $avail -X $X -Y $cursorY
            [void]$resolvedChildren.Add($rc)
            $cursorY += $rc.Height
        }
    }

    return [PSCustomObject]@{
        Type          = 'Box'
        Direction     = $Node.Direction
        Children      = $resolvedChildren.ToArray()
        Style         = $Node.Style
        Width         = $resolvedWidth
        Height        = $resolvedHeight
        NaturalWidth  = $Node.NaturalWidth
        NaturalHeight = $Node.NaturalHeight
        X             = $X
        Y             = $Y
    }
}

function Measure-ElmViewTree {
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
        PSCustomObject — a new tree with the same structure as the input but with
        X, Y, Width, Height, NaturalWidth, and NaturalHeight fields on every node.

    .EXAMPLE
        $tree     = New-ElmBox -Children @(New-ElmText -Content 'Hello') -Width 'Fill'
        $measured = Measure-ElmViewTree -Root $tree -TermWidth 80 -TermHeight 24

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

    $withNatural = Invoke-ElmPass1 -Node $Root
    $measured    = Invoke-ElmPass2 -Node $withNatural -AvailableWidth $TermWidth -AvailableHeight $TermHeight -X 0 -Y 0
    return $measured
}
