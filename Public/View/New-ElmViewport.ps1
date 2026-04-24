function New-ElmViewport {
    <#
    .SYNOPSIS
        Creates a scrollable text viewport view node.

    .DESCRIPTION
        Returns a Box view node showing a fixed-height window into an array of
        text lines. The caller manages ScrollOffset in the model and increments
        or decrements it via key subscriptions.

        Only lines in the range [ScrollOffset, ScrollOffset + MaxVisible) are
        rendered. Lines outside the window are not included in the view tree.

    .PARAMETER Lines
        Array of strings to display. Required.

    .PARAMETER ScrollOffset
        Zero-based index of the first visible line. Clamped so the window
        never extends past the end of Lines. Default: 0.

    .PARAMETER MaxVisible
        Number of lines to show at once. Default: 10.

    .PARAMETER Style
        Optional Elm style applied to each line.

    .OUTPUTS
        PSCustomObject — Box view node.

    .EXAMPLE
        New-ElmViewport -Lines $model.Lines -ScrollOffset $model.Scroll -MaxVisible 20

    .EXAMPLE
        $dimStyle = New-ElmStyle -Foreground 'BrightBlack'
        New-ElmViewport -Lines $logLines -ScrollOffset $model.Top -MaxVisible 15 -Style $dimStyle

    .NOTES
        To implement scroll-to-bottom, set ScrollOffset to
        [math]::Max(0, $lines.Count - $MaxVisible) before passing to this function.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines,

        [Parameter()]
        [int]$ScrollOffset = 0,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$MaxVisible = 10,

        [Parameter()]
        [PSCustomObject]$Style = $null
    )

    $count = $Lines.Count

    if ($count -eq 0) {
        return [PSCustomObject]@{
            Type      = 'Box'
            Direction = 'Vertical'
            Children  = @([PSCustomObject]@{ Type = 'Text'; Content = ''; Style = $null; Width = 'Auto'; Height = 'Auto' })
            Style     = $Style
            Width     = 'Auto'
            Height    = 'Auto'
        }
    }

    # Clamp offset
    $maxOffset = [math]::Max(0, $count - $MaxVisible)
    $offset    = [math]::Max(0, [math]::Min($ScrollOffset, $maxOffset))
    $endIdx    = [math]::Min($offset + $MaxVisible, $count) - 1

    $children = [System.Collections.Generic.List[object]]::new()
    for ($i = $offset; $i -le $endIdx; $i++) {
        $children.Add([PSCustomObject]@{
            Type    = 'Text'
            Content = $Lines[$i]
            Style   = $Style
            Width   = 'Auto'
            Height  = 'Auto'
        })
    }

    return [PSCustomObject]@{
        Type      = 'Box'
        Direction = 'Vertical'
        Children  = $children.ToArray()
        Style     = $null
        Width     = 'Auto'
        Height    = 'Auto'
    }
}
