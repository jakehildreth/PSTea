function New-ElmText {
    <#
    .SYNOPSIS
        Creates a Text view node for the Elm view tree.

    .DESCRIPTION
        Returns a PSCustomObject representing a leaf text node. The content string is
        rendered at the position assigned by Measure-ElmViewTree. An optional Style
        controls visual appearance (colors, decorations, padding, border, etc.).

    .PARAMETER Content
        The string to display. Required; must not be null or empty.

    .PARAMETER Style
        An Elm style PSCustomObject created by New-ElmStyle. When omitted, no styling
        is applied and the text is rendered as-is.

    .OUTPUTS
        PSCustomObject with Type, Content, Style, Width, Height properties.

    .EXAMPLE
        New-ElmText -Content 'Hello, world!'

    .EXAMPLE
        $style = New-ElmStyle -Foreground '#88C0D0' -Bold
        New-ElmText -Content 'Status: OK' -Style $style

    .NOTES
        Width and Height default to 'Auto'. They are resolved by Measure-ElmViewTree
        based on content length and style padding/border settings.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Content,

        [Parameter()]
        [PSCustomObject]$Style = $null
    )

    return [PSCustomObject]@{
        Type    = 'Text'
        Content = $Content
        Style   = $Style
        Width   = 'Auto'
        Height  = 'Auto'
    }
}
