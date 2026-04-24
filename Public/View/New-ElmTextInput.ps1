function New-ElmTextInput {
    <#
    .SYNOPSIS
        Creates a single-line text input view node.

    .DESCRIPTION
        Returns a Text view node representing an editable text field. The caller
        manages Value and CursorPos in the model; key subscriptions forward
        character keys and control keys (Backspace, Left, Right, Home, End) to
        the update function, which mutates Value/CursorPos and passes them here.

        Rendered example (focused, cursor at position 5):

            [ hello| world ]

        When unfocused:

            [ hello world ]

        Placeholder text is shown when Value is empty and the field is not focused.

    .PARAMETER Value
        Current string value of the input. Default: empty string.

    .PARAMETER CursorPos
        Zero-based cursor position within Value. Clamped to [0, Value.Length].
        Default: 0. Only rendered when -Focused is present.

    .PARAMETER Focused
        When present, renders a cursor character at CursorPos and applies
        FocusedStyle instead of Style.

    .PARAMETER Placeholder
        Text shown when Value is empty and -Focused is not set. Default: ''.

    .PARAMETER CursorChar
        Character used to represent the cursor. Default: '|'.

    .PARAMETER Style
        Elm style applied when the field is not focused.

    .PARAMETER FocusedStyle
        Elm style applied when the field is focused. When omitted and -Focused
        is set, falls back to Style.

    .OUTPUTS
        PSCustomObject — Text view node.

    .EXAMPLE
        New-ElmTextInput -Value $model.Input -CursorPos $model.Cursor -Focused

    .EXAMPLE
        $focStyle = New-ElmStyle -Foreground 'BrightWhite' -Underline
        New-ElmTextInput -Value $model.Search -CursorPos $model.Cursor `
                         -Focused:$model.InputFocused `
                         -Placeholder 'Type to search...' `
                         -FocusedStyle $focStyle

    .NOTES
        This widget is purely a view helper. Use key subscriptions or TickMs to
        handle Backspace, Delete, character insertion, cursor movement, etc. in
        the Update function.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowEmptyString()]
        [string]$Value = '',

        [Parameter()]
        [int]$CursorPos = 0,

        [Parameter()]
        [switch]$Focused,

        [Parameter()]
        [AllowEmptyString()]
        [string]$Placeholder = '',

        [Parameter()]
        [ValidateLength(1, 1)]
        [string]$CursorChar = '|',

        [Parameter()]
        [PSCustomObject]$Style = $null,

        [Parameter()]
        [PSCustomObject]$FocusedStyle = $null
    )

    # Clamp cursor
    $clampedCursor = [math]::Max(0, [math]::Min($CursorPos, $Value.Length))

    $activeStyle = if ($Focused.IsPresent -and $null -ne $FocusedStyle) {
        $FocusedStyle
    } else {
        $Style
    }

    $content = if ($Focused.IsPresent) {
        # Insert cursor character at position
        $before = $Value.Substring(0, $clampedCursor)
        $after  = $Value.Substring($clampedCursor)
        $before + $CursorChar + $after
    } elseif ($Value.Length -eq 0 -and $Placeholder.Length -gt 0) {
        $Placeholder
    } else {
        $Value
    }

    return [PSCustomObject]@{
        Type    = 'Text'
        Content = $content
        Style   = $activeStyle
        Width   = 'Auto'
        Height  = 'Auto'
    }
}
