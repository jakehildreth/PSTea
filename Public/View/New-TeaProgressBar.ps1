function New-TeaProgressBar {
    <#
    .SYNOPSIS
        Creates a horizontal progress bar view node.

    .DESCRIPTION
        Returns a Text view node representing a filled progress bar.
        The caller supplies a value between 0.0 and 1.0 (or 0-100 when -Percent
        is used) and a display width. The bar is rendered as:

            [########--------]

        where '#' is the filled portion and '-' is the empty portion.

    .PARAMETER Value
        Fill ratio from 0.0 (empty) to 1.0 (full). Values outside this range
        are clamped. Use -Percent to supply a 0-100 integer instead.

    .PARAMETER Percent
        Fill value from 0 to 100. Converted to a 0.0-1.0 ratio internally.
        Mutually exclusive with -Value.

    .PARAMETER Width
        Total display width including brackets. Minimum 4. Default 20.

    .PARAMETER FilledChar
        Single character used for the filled portion. Default '#'.

    .PARAMETER EmptyChar
        Single character used for the empty portion. Default '-'.

    .PARAMETER Style
        Optional Tea style PSCustomObject from New-TeaStyle.

    .OUTPUTS
        PSCustomObject - Text view node.

    .EXAMPLE
        New-TeaProgressBar -Value 0.75 -Width 30

    .EXAMPLE
        New-TeaProgressBar -Percent 50 -Width 20 -Style (New-TeaStyle -Foreground 'Green')

    .NOTES
        The bar always includes surrounding brackets [ ], so the inner fill area
        is Width - 2 characters wide.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Ratio')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Ratio')]
        [double]$Value,

        [Parameter(Mandatory, ParameterSetName = 'Percent')]
        [ValidateRange(0, 100)]
        [int]$Percent,

        [Parameter()]
        [ValidateRange(4, [int]::MaxValue)]
        [int]$Width = 20,

        [Parameter()]
        [ValidateLength(1, 1)]
        [string]$FilledChar = '#',

        [Parameter()]
        [ValidateLength(1, 1)]
        [string]$EmptyChar = '-',

        [Parameter()]
        [PSCustomObject]$Style = $null
    )

    $ratio = if ($PSCmdlet.ParameterSetName -eq 'Percent') {
        $Percent / 100.0
    } else {
        $Value
    }

    # Clamp to [0.0, 1.0]
    if ($ratio -lt 0.0) { $ratio = 0.0 }
    if ($ratio -gt 1.0) { $ratio = 1.0 }

    $innerWidth = $Width - 2
    $filled     = [int][math]::Round($ratio * $innerWidth)
    $empty      = $innerWidth - $filled

    $bar = '[' + ([string]$FilledChar * $filled) + ([string]$EmptyChar * $empty) + ']'

    return [PSCustomObject]@{
        Type    = 'Text'
        Content = $bar
        Style   = $Style
        Width   = 'Auto'
        Height  = 'Auto'
    }
}

Set-Alias -Name TeaProgressBar       -Value New-TeaProgressBar
