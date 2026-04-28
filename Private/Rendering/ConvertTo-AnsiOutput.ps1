function ConvertTo-AnsiOutput {
    <#
    .SYNOPSIS
        Renders a fully-measured view tree as a complete ANSI escape sequence string.

    .DESCRIPTION
        Walks the measured view tree produced by Measure-TeaViewTree. For each leaf
        Text node, emits a cursor-position sequence (ESC[{Y+1};{X+1}H) followed by
        the styled content from Apply-TeaStyle. The output is prefixed with a
        clear-screen (ESC[2J) sequence.

        Does not emit hide/show cursor sequences - cursor visibility is managed by
        the event loop's try/finally block. Use this for the initial render or after
        a FullRedraw patch. For incremental updates, use ConvertTo-AnsiPatch instead.

    .PARAMETER Root
        The root of a measured view tree (output of Measure-TeaViewTree).

    .OUTPUTS
        [string] - A single ANSI escape sequence string ready for Console output.

    .EXAMPLE
        $tree     = New-TeaBox -Children @(New-TeaText -Content 'Hello') -Width 'Fill'
        $measured = Measure-TeaViewTree -Root $tree -TermWidth 80 -TermHeight 24
        $ansi     = ConvertTo-AnsiOutput -Root $measured
        [Console]::Out.Write($ansi)

    .NOTES
        Caller is responsible for flushing the output queue. Box nodes are traversed
        but do not themselves emit any ANSI sequences in the current implementation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Root
    )

    $esc = [char]27
    $sb  = [System.Text.StringBuilder]::new()

    [void]$sb.Append("$esc[2J")

    $stack = [System.Collections.Stack]::new()
    $stack.Push($Root)

    while ($stack.Count -gt 0) {
        $node = $stack.Pop()

        if ($node.Type -eq 'Text') {
            $row     = $node.Y + 1
            $col     = $node.X + 1
            $content = Apply-TeaStyle -Content $node.Content -Style $node.Style -Width $node.Width
            [void]$sb.Append("$esc[$row;${col}H$content")
        } elseif ($node.Type -eq 'Box') {
            for ($i = $node.Children.Count - 1; $i -ge 0; $i--) {
                $stack.Push($node.Children[$i])
            }
        }
    }

    return $sb.ToString()
}


