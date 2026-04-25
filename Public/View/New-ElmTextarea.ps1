function New-ElmTextarea {
    <#
    .SYNOPSIS
        Creates a multi-line text area view node.

    .DESCRIPTION
        Returns a Box (Vertical) view node representing a multi-line editable text
        area. The caller manages Lines, CursorRow, CursorCol, and ScrollOffset in
        the model. Key subscriptions forward character input, Backspace, Enter,
        and cursor movement to the update function.

        When focused, a cursor character is inserted into the rendered cursor row
        at CursorCol. ScrollOffset controls which lines are visible. Lines outside
        the [ScrollOffset, ScrollOffset + MaxVisible) window are not rendered.

        Rendered example (MaxVisible=4, focused, cursor on row 1 col 3):

            Line one
            Lin|e two
            Line three
            Line four

        Placeholder text is shown when Lines is empty or a single empty string
        and the widget is not focused.

    .PARAMETER Lines
        Array of strings; each element is one line of text. Required.

    .PARAMETER CursorRow
        Zero-based row index of the cursor. Clamped to [0, Lines.Count-1].
        Default: 0.

    .PARAMETER CursorCol
        Zero-based column index within the cursor row. Clamped to
        [0, Lines[CursorRow].Length]. Default: 0.

    .PARAMETER Focused
        When present, renders a cursor character at (CursorRow, CursorCol) and
        applies FocusedStyle instead of Style.

    .PARAMETER MaxVisible
        Number of lines to render at once. Default: 10.

    .PARAMETER ScrollOffset
        Zero-based index of the first visible line. Clamped so the window never
        extends past the end of Lines. Default: 0.

    .PARAMETER Placeholder
        Text shown as a single line when Lines is empty (or a single empty string)
        and -Focused is not set. Default: ''.

    .PARAMETER CursorChar
        Single character used to represent the cursor. Default: '|'.

    .PARAMETER Style
        Elm style applied to each line when the widget is not focused.

    .PARAMETER FocusedStyle
        Elm style applied to each line when the widget is focused. When omitted
        and -Focused is set, falls back to Style.

    .PARAMETER FocusedBoxStyle
        When provided and -Focused is set, applied as the Style of the outer
        Box node. Use to add a visible border around the focused area, e.g.:

            New-ElmStyle -Border 'Rounded' -Foreground 'BrightWhite'

        When null (default) or when unfocused, the outer Box has no Style.

    .OUTPUTS
        PSCustomObject — Box (Vertical) view node.

    .EXAMPLE
        New-ElmTextarea -Lines $model.Lines -CursorRow $model.Row -CursorCol $model.Col -Focused

    .EXAMPLE
        $focStyle = New-ElmStyle -Foreground 'BrightWhite'
        New-ElmTextarea -Lines $model.Body -CursorRow $model.Row -CursorCol $model.Col `
                        -Focused:$model.Editing `
                        -MaxVisible 20 -ScrollOffset $model.Scroll `
                        -Placeholder 'Start typing...' `
                        -FocusedStyle $focStyle

    .NOTES
        This widget is purely a view helper. Implement line splitting on Enter,
        line joining on Backspace-at-start, and cursor clamping in the Update
        function using key and char subscriptions.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines,

        [Parameter()]
        [int]$CursorRow = 0,

        [Parameter()]
        [int]$CursorCol = 0,

        [Parameter()]
        [switch]$Focused,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$MaxVisible = 10,

        [Parameter()]
        [int]$ScrollOffset = 0,

        [Parameter()]
        [AllowEmptyString()]
        [string]$Placeholder = '',

        [Parameter()]
        [ValidateLength(1, 1)]
        [string]$CursorChar = '|',

        [Parameter()]
        [PSCustomObject]$Style = $null,

        [Parameter()]
        [PSCustomObject]$FocusedStyle = $null,

        [Parameter()]
        [PSCustomObject]$FocusedBoxStyle = $null
    )

    $activeStyle = if ($Focused.IsPresent -and $null -ne $FocusedStyle) {
        $FocusedStyle
    } else {
        $Style
    }

    # Normalise empty input to a single empty line.
    # @() ensures we always get an array: in PS, an if-else expression
    # returns pipeline output which unboxes a single-element [string[]] to a
    # scalar string; indexing a scalar string then returns [char] not [string].
    $lineList  = @(if ($Lines.Count -eq 0) { '' } else { $Lines })
    $lineCount = $lineList.Count

    # Show placeholder when empty and unfocused
    $isEmpty = $lineCount -eq 1 -and $lineList[0].Length -eq 0
    if ($isEmpty -and -not $Focused.IsPresent -and $Placeholder.Length -gt 0) {
        return [PSCustomObject]@{
            Type      = 'Box'
            Direction = 'Vertical'
            Children  = @([PSCustomObject]@{
                Type    = 'Text'
                Content = $Placeholder
                Style   = $Style
                Width   = 'Auto'
                Height  = 'Auto'
            })
            Style     = $activeStyle
            Width     = 'Auto'
            Height    = 'Auto'
        }
    }

    # Clamp cursor row and col
    $clampedRow = [math]::Max(0, [math]::Min($CursorRow, $lineCount - 1))
    $cursorLine = [string]$lineList[$clampedRow]
    $clampedCol = [math]::Max(0, [math]::Min($CursorCol, $cursorLine.Length))

    # Clamp scroll offset
    $maxOffset = [math]::Max(0, $lineCount - $MaxVisible)
    $offset    = [math]::Max(0, [math]::Min($ScrollOffset, $maxOffset))
    $endIdx    = [math]::Min($offset + $MaxVisible, $lineCount) - 1

    $children = [System.Collections.Generic.List[object]]::new()
    for ($i = $offset; $i -le $endIdx; $i++) {
        $line    = [string]$lineList[$i]
        $content = if ($Focused.IsPresent -and $i -eq $clampedRow) {
            $before = $line.Substring(0, $clampedCol)
            $after  = $line.Substring($clampedCol)
            $before + $CursorChar + $after
        } else {
            $line
        }
        $children.Add([PSCustomObject]@{
            Type    = 'Text'
            Content = $content
            Style   = $activeStyle
            Width   = 'Auto'
            Height  = 'Auto'
        })
    }

    $outerBoxStyle = if ($Focused.IsPresent -and $null -ne $FocusedBoxStyle) { $FocusedBoxStyle } else { $null }

    return [PSCustomObject]@{
        Type      = 'Box'
        Direction = 'Vertical'
        Children  = $children.ToArray()
        Style     = $outerBoxStyle
        Width     = 'Auto'
        Height    = 'Auto'
    }
}
