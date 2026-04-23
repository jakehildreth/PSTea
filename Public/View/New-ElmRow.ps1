function New-ElmRow {
    <#
    .SYNOPSIS
        Creates a horizontal Row view node for the Elm view tree.

    .DESCRIPTION
        Returns a PSCustomObject representing a container node that arranges its children
        horizontally (Direction = 'Horizontal'). Use New-ElmBox for vertical layout.

    .PARAMETER Children
        An array of child view nodes. Required; must not be null (can be empty).

    .PARAMETER Style
        An Elm style PSCustomObject created by New-ElmStyle. Controls colors, border,
        padding, and margin applied to the row itself.

    .PARAMETER Width
        Width override. Accepts 'Auto' (default), 'Fill', an integer (columns), or a
        percentage string like '50%'. Resolved by Measure-ElmViewTree.

    .PARAMETER Height
        Height override. Same format as -Width.

    .OUTPUTS
        PSCustomObject with Type, Direction, Children, Style, Width, Height properties.

    .EXAMPLE
        New-ElmRow -Children @(
            New-ElmBox -Children @($leftContent) -Width '50%'
            New-ElmBox -Children @($rightContent) -Width '50%'
        ) -Width 'Fill'

    .EXAMPLE
        New-ElmRow -Children @($label, $value) -Style (New-ElmStyle -Background '#3B4252')

    .NOTES
        Direction is always 'Horizontal'. Use New-ElmBox for 'Vertical'.
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
