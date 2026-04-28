function New-TeaStyle {
    <#
    .SYNOPSIS
        Creates a composable style object for PSTea view nodes.

    .DESCRIPTION
        Returns a PSCustomObject describing visual style attributes: colors, text decorations,
        border, padding, margin, alignment, and dimension overrides. All parameters are optional.
        Use -Base to inherit from an existing style and selectively override fields.

    .PARAMETER Foreground
        Foreground color. Accepts a hex string ('#RRGGBB'), a 256-color index (int 0-255),
        or a named ANSI color string (e.g. 'Red', 'BrightCyan').

    .PARAMETER Background
        Background color. Same format as -Foreground.

    .PARAMETER Bold
        Applies bold text decoration.

    .PARAMETER Italic
        Applies italic text decoration.

    .PARAMETER Underline
        Applies underline text decoration.

    .PARAMETER Strikethrough
        Applies strikethrough text decoration.

    .PARAMETER Border
        Border style. One of: None, Normal, Rounded, Thick, Double. Default: None.

    .PARAMETER Padding
        Inner spacing between content and border. Accepts 1, 2, or 4 int values using
        CSS shorthand: 1 value = all sides; 2 values = top/bottom, left/right;
        4 values = top, right, bottom, left.

    .PARAMETER PaddingTop
        Inner spacing on the top side only. Overrides the top value set by -Padding.

    .PARAMETER PaddingRight
        Inner spacing on the right side only. Overrides the right value set by -Padding.

    .PARAMETER PaddingBottom
        Inner spacing on the bottom side only. Overrides the bottom value set by -Padding.

    .PARAMETER PaddingLeft
        Inner spacing on the left side only. Overrides the left value set by -Padding.

    .PARAMETER Margin
        Outer spacing around the border. Same shorthand as -Padding.

    .PARAMETER MarginTop
        Outer spacing on the top side only. Overrides the top value set by -Margin.

    .PARAMETER MarginRight
        Outer spacing on the right side only. Overrides the right value set by -Margin.

    .PARAMETER MarginBottom
        Outer spacing on the bottom side only. Overrides the bottom value set by -Margin.

    .PARAMETER MarginLeft
        Outer spacing on the left side only. Overrides the left value set by -Margin.

    .PARAMETER Align
        Horizontal text alignment within the allocated width. One of: Left, Center, Right.
        Default: Left.

    .PARAMETER Width
        Override width for this node. Accepts 'Fill', 'Auto', an integer (columns), or
        a percentage string like '50%'.

    .PARAMETER Height
        Override height for this node. Same format as -Width.

    .PARAMETER Base
        A base style PSCustomObject to inherit from. Any explicitly specified parameters
        override the corresponding base fields.

    .OUTPUTS
        PSCustomObject with all style fields explicitly set.

    .EXAMPLE
        $style = New-TeaStyle -Foreground '#88C0D0' -Bold -Border 'Rounded' -Padding 1

    .EXAMPLE
        $active = New-TeaStyle -Base $style -Background '#5C4AE4'

    .NOTES
        All fields are always present on the returned object - no $null ambiguity for consumers.
    #>
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param(
        [Parameter()]
        [object]$Foreground = $null,

        [Parameter()]
        [object]$Background = $null,

        [Parameter()]
        [switch]$Bold,

        [Parameter()]
        [switch]$Italic,

        [Parameter()]
        [switch]$Underline,

        [Parameter()]
        [switch]$Strikethrough,

        [Parameter()]
        [ValidateSet('None', 'Normal', 'Rounded', 'Thick', 'Double')]
        [string]$Border = 'None',

        [Parameter()]
        [int[]]$Padding,

        [Parameter()]
        [int]$PaddingTop,

        [Parameter()]
        [int]$PaddingRight,

        [Parameter()]
        [int]$PaddingBottom,

        [Parameter()]
        [int]$PaddingLeft,

        [Parameter()]
        [int[]]$Margin,

        [Parameter()]
        [int]$MarginTop,

        [Parameter()]
        [int]$MarginRight,

        [Parameter()]
        [int]$MarginBottom,

        [Parameter()]
        [int]$MarginLeft,

        [Parameter()]
        [ValidateSet('Left', 'Center', 'Right')]
        [string]$Align = 'Left',

        [Parameter()]
        [object]$Width = $null,

        [Parameter()]
        [object]$Height = $null,

        [Parameter()]
        [PSCustomObject]$Base = $null
    )

    # Start with defaults
    $style = [PSCustomObject]@{
        Foreground    = $null
        Background    = $null
        Bold          = $false
        Italic        = $false
        Underline     = $false
        Strikethrough = $false
        Border        = 'None'
        PaddingTop    = 0
        PaddingRight  = 0
        PaddingBottom = 0
        PaddingLeft   = 0
        MarginTop     = 0
        MarginRight   = 0
        MarginBottom  = 0
        MarginLeft    = 0
        Align         = 'Left'
        Width         = $null
        Height        = $null
    }

    # Copy all fields from base if provided
    if ($null -ne $Base) {
        $style.Foreground    = $Base.Foreground
        $style.Background    = $Base.Background
        $style.Bold          = $Base.Bold
        $style.Italic        = $Base.Italic
        $style.Underline     = $Base.Underline
        $style.Strikethrough = $Base.Strikethrough
        $style.Border        = $Base.Border
        $style.PaddingTop    = $Base.PaddingTop
        $style.PaddingRight  = $Base.PaddingRight
        $style.PaddingBottom = $Base.PaddingBottom
        $style.PaddingLeft   = $Base.PaddingLeft
        $style.MarginTop     = $Base.MarginTop
        $style.MarginRight   = $Base.MarginRight
        $style.MarginBottom  = $Base.MarginBottom
        $style.MarginLeft    = $Base.MarginLeft
        $style.Align         = $Base.Align
        $style.Width         = $Base.Width
        $style.Height        = $Base.Height
    }

    # Apply explicitly bound parameters (override base or defaults)
    if ($PSBoundParameters.ContainsKey('Foreground'))    { $style.Foreground    = $Foreground }
    if ($PSBoundParameters.ContainsKey('Background'))    { $style.Background    = $Background }
    if ($PSBoundParameters.ContainsKey('Bold'))          { $style.Bold          = $Bold.IsPresent }
    if ($PSBoundParameters.ContainsKey('Italic'))        { $style.Italic        = $Italic.IsPresent }
    if ($PSBoundParameters.ContainsKey('Underline'))     { $style.Underline     = $Underline.IsPresent }
    if ($PSBoundParameters.ContainsKey('Strikethrough')) { $style.Strikethrough = $Strikethrough.IsPresent }
    if ($PSBoundParameters.ContainsKey('Border'))        { $style.Border        = $Border }
    if ($PSBoundParameters.ContainsKey('Align'))         { $style.Align         = $Align }
    if ($PSBoundParameters.ContainsKey('Width'))         { $style.Width         = $Width }
    if ($PSBoundParameters.ContainsKey('Height'))        { $style.Height        = $Height }

    if ($PSBoundParameters.ContainsKey('Padding')) {
        switch ($Padding.Count) {
            1 {
                $style.PaddingTop    = $Padding[0]
                $style.PaddingRight  = $Padding[0]
                $style.PaddingBottom = $Padding[0]
                $style.PaddingLeft   = $Padding[0]
            }
            2 {
                $style.PaddingTop    = $Padding[0]
                $style.PaddingBottom = $Padding[0]
                $style.PaddingRight  = $Padding[1]
                $style.PaddingLeft   = $Padding[1]
            }
            4 {
                $style.PaddingTop    = $Padding[0]
                $style.PaddingRight  = $Padding[1]
                $style.PaddingBottom = $Padding[2]
                $style.PaddingLeft   = $Padding[3]
            }
        }
    }

    if ($PSBoundParameters.ContainsKey('Margin')) {
        switch ($Margin.Count) {
            1 {
                $style.MarginTop    = $Margin[0]
                $style.MarginRight  = $Margin[0]
                $style.MarginBottom = $Margin[0]
                $style.MarginLeft   = $Margin[0]
            }
            2 {
                $style.MarginTop    = $Margin[0]
                $style.MarginBottom = $Margin[0]
                $style.MarginRight  = $Margin[1]
                $style.MarginLeft   = $Margin[1]
            }
            4 {
                $style.MarginTop    = $Margin[0]
                $style.MarginRight  = $Margin[1]
                $style.MarginBottom = $Margin[2]
                $style.MarginLeft   = $Margin[3]
            }
        }
    }

    # Individual direction overrides (applied after shorthand so they win)
    if ($PSBoundParameters.ContainsKey('PaddingTop'))    { $style.PaddingTop    = $PaddingTop }
    if ($PSBoundParameters.ContainsKey('PaddingRight'))  { $style.PaddingRight  = $PaddingRight }
    if ($PSBoundParameters.ContainsKey('PaddingBottom')) { $style.PaddingBottom = $PaddingBottom }
    if ($PSBoundParameters.ContainsKey('PaddingLeft'))   { $style.PaddingLeft   = $PaddingLeft }
    if ($PSBoundParameters.ContainsKey('MarginTop'))     { $style.MarginTop     = $MarginTop }
    if ($PSBoundParameters.ContainsKey('MarginRight'))   { $style.MarginRight   = $MarginRight }
    if ($PSBoundParameters.ContainsKey('MarginBottom'))  { $style.MarginBottom  = $MarginBottom }
    if ($PSBoundParameters.ContainsKey('MarginLeft'))    { $style.MarginLeft    = $MarginLeft }

    return $style
}

Set-Alias -Name TeaStyle             -Value New-TeaStyle
