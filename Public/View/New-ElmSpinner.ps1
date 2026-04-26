function New-ElmSpinner {
    <#
    .SYNOPSIS
        Creates an animated spinner view node driven by a frame counter.

    .DESCRIPTION
        Returns a Text view node showing the current frame of a spinner animation.
        The caller increments Frame (typically via a Tick message from a timer
        subscription) and the spinner cycles through its character sequence.

        Built-in styles (selectable via -Variant):
          Dots   : | / - \
          Braille: ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏
          Bounce : . o O o
          Arrow  : > >> >>> >> >

        Custom frame sequences can be provided via -Frames.

    .PARAMETER Frame
        Current frame index. Modulo the frame count is applied automatically,
        so any non-negative integer is valid. Typical usage: store an int in
        the model and increment it on each Tick.

    .PARAMETER Variant
        Predefined spinner style. One of: Dots, Braille, Bounce, Arrow.
        Default: Dots. Ignored when -Frames is provided.

    .PARAMETER Frames
        Custom array of strings, one per animation frame. Overrides -Variant.

    .PARAMETER Style
        Optional Elm style PSCustomObject from New-ElmStyle.

    .OUTPUTS
        PSCustomObject - Text view node.

    .EXAMPLE
        # In view function:
        New-ElmSpinner -Frame $model.TickCount

    .EXAMPLE
        New-ElmSpinner -Frame $model.Frame -Variant Braille -Style (New-ElmStyle -Foreground 'Cyan')

    .NOTES
        The frame counter wraps automatically, so it is safe to increment it
        indefinitely without overflow concern in normal use.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$Frame,

        [Parameter()]
        [ValidateSet('Dots', 'Braille', 'Bounce', 'Arrow')]
        [string]$Variant = 'Dots',

        [Parameter()]
        [string[]]$Frames = $null,

        [Parameter()]
        [PSCustomObject]$Style = $null
    )

    $frameSet = if ($null -ne $Frames -and $Frames.Count -gt 0) {
        $Frames
    } else {
        switch ($Variant) {
            'Dots'    { @('|', '/', '-', '\') }
            'Braille' { @([char]0x280B, [char]0x2819, [char]0x2839, [char]0x2838,
                          [char]0x283C, [char]0x2834, [char]0x2826, [char]0x2827,
                          [char]0x2807, [char]0x280F) }
            'Bounce'  { @('.', 'o', 'O', 'o') }
            'Arrow'   { @('>', '>>', '>>>', '>>') }
        }
    }

    $char = $frameSet[$Frame % $frameSet.Count]

    return [PSCustomObject]@{
        Type    = 'Text'
        Content = [string]$char
        Style   = $Style
        Width   = 'Auto'
        Height  = 'Auto'
    }
}
