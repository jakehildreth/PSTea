function New-TeaBox {
    <#
    .SYNOPSIS
        Creates a vertical Box view node for the PSTea view tree.

    .DESCRIPTION
        Returns a PSCustomObject representing a container node that stacks its children
        vertically (Direction = 'Vertical'). Use New-TeaRow for horizontal layout.

    .PARAMETER Children
        An array of child view nodes. Required; must not be null (can be empty).

    .PARAMETER Style
        A Tea style PSCustomObject created by New-TeaStyle. Controls colors, border,
        padding, and margin applied to the box itself.

    .PARAMETER Width
        Width override. Accepts 'Auto' (default), 'Fill', an integer (columns), or a
        percentage string like '50%'. Resolved by Measure-TeaViewTree.

    .PARAMETER Height
        Height override. Same format as -Width.

    .OUTPUTS
        PSCustomObject with Type, Direction, Children, Style, Width, Height properties.

    .EXAMPLE
        New-TeaBox -Children @(
            New-TeaText -Content 'Line 1'
            New-TeaText -Content 'Line 2'
        )

    .EXAMPLE
        New-TeaBox -Children @($header, $body) -Width 'Fill' -Style (New-TeaStyle -Border 'Rounded')

    .NOTES
        Direction is always 'Vertical'. Use New-TeaRow for 'Horizontal'.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [ValidateNotNull()]
        [object[]]$Children,

        [Parameter()]
        [PSCustomObject]$Style = $null,

        [Parameter()]
        [object]$Width = 'Auto',

        [Parameter()]
        [object]$Height = 'Auto'
    )

    return [PSCustomObject]@{
        Type      = 'Box'
        Direction = 'Vertical'
        Children  = $Children
        Style     = $Style
        Width     = $Width
        Height    = $Height
    }
}

Set-Alias -Name TeaBox               -Value New-TeaBox
