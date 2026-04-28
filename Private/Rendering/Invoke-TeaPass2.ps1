function Invoke-TeaPass2 {
    <#
    .SYNOPSIS
        Pass 2 of the two-pass layout algorithm: resolve final sizes and positions top-down.

    .DESCRIPTION
        Takes a node annotated by Invoke-TeaPass1 and resolves Fill/percentage widths and
        heights against the available space, assigns absolute X/Y positions, and recurses
        into children. The output tree has every node fully resolved for rendering.

    .PARAMETER Node
        The annotated node from Invoke-TeaPass1.

    .PARAMETER AvailableWidth
        Available horizontal pixels for this node.

    .PARAMETER AvailableHeight
        Available vertical pixels for this node.

    .PARAMETER X
        Absolute X origin for this node.

    .PARAMETER Y
        Absolute Y origin for this node.

    .OUTPUTS
        PSCustomObject - fully-resolved node tree ready for ANSI rendering.
    #>
    [CmdletBinding()]
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

    $resolvedWidth  = Resolve-TeaDimension -Value $Node.Width  -Available $AvailableWidth  -Natural $Node.NaturalWidth
    $resolvedHeight = Resolve-TeaDimension -Value $Node.Height -Available $AvailableHeight -Natural $Node.NaturalHeight

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

    # Box node - distribute space to children
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
                $w = Resolve-TeaDimension -Value $child.Width -Available $resolvedWidth -Natural $child.NaturalWidth
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
            $rc = Invoke-TeaPass2 -Node $child -AvailableWidth $avail -AvailableHeight $resolvedHeight -X $cursorX -Y $Y
            [void]$resolvedChildren.Add($rc)
            $cursorX += $rc.Width
        }
    } else {
        # Vertical - same pattern, distributing height
        $childResolvedH = @{}
        $fixedTotal     = 0
        $fillCount      = 0

        for ($i = 0; $i -lt $Node.Children.Count; $i++) {
            $child = $Node.Children[$i]
            if ($child.Height -eq 'Fill') {
                $fillCount++
                $childResolvedH[$i] = $null
            } else {
                $h = Resolve-TeaDimension -Value $child.Height -Available $resolvedHeight -Natural $child.NaturalHeight
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
            $rc = Invoke-TeaPass2 -Node $child -AvailableWidth $resolvedWidth -AvailableHeight $avail -X $X -Y $cursorY
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
