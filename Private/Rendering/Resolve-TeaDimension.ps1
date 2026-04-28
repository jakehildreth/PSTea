function Resolve-TeaDimension {
    <#
    .SYNOPSIS
        Resolves a dimension value to a concrete integer pixel count.

    .DESCRIPTION
        Accepts Auto, Fill, an integer, or a percentage string (e.g. '50%') and converts
        it to a concrete pixel value relative to the available and natural sizes.

    .PARAMETER Value
        The dimension value: 'Auto', 'Fill', an [int], or a percentage string like '50%'.

    .PARAMETER Available
        The number of available pixels in the containing axis.

    .PARAMETER Natural
        The natural (content-driven) size of the node.

    .OUTPUTS
        [int] - Resolved pixel count.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [object]$Value,

        [Parameter()]
        [int]$Available,

        [Parameter()]
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
