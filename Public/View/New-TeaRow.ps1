function New-TeaRow {
    <#
    .SYNOPSIS
        Creates a horizontal Row view node for the PSTea view tree.

    .DESCRIPTION
        Returns a PSCustomObject representing a container node that arranges its children
        horizontally (Direction = 'Horizontal'). Use New-TeaBox for vertical layout.

    .PARAMETER Children
        An array of child view nodes. Required; must not be null (can be empty).

    .PARAMETER Style
        A Tea style PSCustomObject created by New-TeaStyle. Controls colors, border,
        padding, and margin applied to the row itself.

    .PARAMETER Width
        Width override. Accepts 'Auto' (default), 'Fill', an integer (columns), or a
        percentage string like '50%'. Resolved by Measure-TeaViewTree.

    .PARAMETER Height
        Height override. Same format as -Width.

    .OUTPUTS
        PSCustomObject with Type, Direction, Children, Style, Width, Height properties.

    .EXAMPLE
        New-TeaRow -Children @(
            New-TeaBox -Children @($leftContent) -Width '50%'
            New-TeaBox -Children @($rightContent) -Width '50%'
        ) -Width 'Fill'

    .EXAMPLE
        New-TeaRow -Children @($label, $value) -Style (New-TeaStyle -Background '#3B4252')

    .NOTES
        Direction is always 'Horizontal'. Use New-TeaBox for 'Vertical'.
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
        Direction = 'Horizontal'
        Children  = $Children
        Style     = $Style
        Width     = $Width
        Height    = $Height
    }
}

Set-Alias -Name TeaRow               -Value New-TeaRow
