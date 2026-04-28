function New-TeaText {
    <#
    .SYNOPSIS
        Creates a Text view node for the PSTea view tree.

    .DESCRIPTION
        Returns a PSCustomObject representing a leaf text node. The content string is
        rendered at the position assigned by Measure-TeaViewTree. An optional Style
        controls visual appearance (colors, decorations, padding, border, etc.).

    .PARAMETER Content
        The string to display. Required; must not be null or empty.

    .PARAMETER Style
        A Tea style PSCustomObject created by New-TeaStyle. When omitted, no styling
        is applied and the text is rendered as-is.

    .OUTPUTS
        PSCustomObject with Type, Content, Style, Width, Height properties.

    .EXAMPLE
        New-TeaText -Content 'Hello, world!'

    .EXAMPLE
        $style = New-TeaStyle -Foreground '#88C0D0' -Bold
        New-TeaText -Content 'Status: OK' -Style $style

    .NOTES
        Width and Height default to 'Auto'. They are resolved by Measure-TeaViewTree
        based on content length and style padding/border settings.
    #>
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
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

Set-Alias -Name TeaText              -Value New-TeaText
