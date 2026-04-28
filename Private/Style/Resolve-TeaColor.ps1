function Resolve-TeaColor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Color,

        [Parameter()]
        [switch]$IsForeground
    )

    $esc = [char]27

    $namedFgCodes = @{
        'Black'         = 30
        'Red'           = 31
        'Green'         = 32
        'Yellow'        = 33
        'Blue'          = 34
        'Magenta'       = 35
        'Cyan'          = 36
        'White'         = 37
        'BrightBlack'   = 90
        'BrightRed'     = 91
        'BrightGreen'   = 92
        'BrightYellow'  = 93
        'BrightBlue'    = 94
        'BrightMagenta' = 95
        'BrightCyan'    = 96
        'BrightWhite'   = 97
    }

    # 256-index integer
    if ($Color -is [int]) {
        if ($IsForeground.IsPresent) {
            return "$esc[38;5;${Color}m"
        } else {
            return "$esc[48;5;${Color}m"
        }
    }

    $colorStr = [string]$Color

    # Hex #RRGGBB
    if ($colorStr -match '^#([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})$') {
        $r = [Convert]::ToInt32($Matches[1], 16)
        $g = [Convert]::ToInt32($Matches[2], 16)
        $b = [Convert]::ToInt32($Matches[3], 16)
        if ($IsForeground.IsPresent) {
            return "$esc[38;2;${r};${g};${b}m"
        } else {
            return "$esc[48;2;${r};${g};${b}m"
        }
    }

    # Stringified 256-index integer
    if ($colorStr -match '^\d+$') {
        $n = [int]$colorStr
        if ($IsForeground.IsPresent) {
            return "$esc[38;5;${n}m"
        } else {
            return "$esc[48;5;${n}m"
        }
    }

    # Named color
    if ($namedFgCodes.ContainsKey($colorStr)) {
        $code = $namedFgCodes[$colorStr]
        if (-not $IsForeground.IsPresent) {
            $code = $code + 10
        }
        return "$esc[${code}m"
    }

    # Invalid
    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
        [System.ArgumentException]::new("Unknown color value: '$colorStr'"),
        'InvalidColor',
        [System.Management.Automation.ErrorCategory]::InvalidArgument,
        $Color
    )
    $PSCmdlet.WriteError($errorRecord)
    return ''
}


