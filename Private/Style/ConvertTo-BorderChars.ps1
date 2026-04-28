function ConvertTo-BorderChars {
    <#
    .SYNOPSIS
        Maps a border style name to a set of Unicode box-drawing characters.

    .DESCRIPTION
        Returns a PSCustomObject with TL, T, TR, L, R, BL, B, BR properties containing
        the appropriate Unicode box-drawing characters for the requested border style.
        Supported styles: None, Normal, Rounded, Thick, Double. Writes a non-terminating
        error and returns the None border set for unknown style names.

    .PARAMETER Style
        The border style name: 'None', 'Normal', 'Rounded', 'Thick', or 'Double'.

    .OUTPUTS
        PSCustomObject with TL, T, TR, L, R, BL, B, BR properties.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Style
    )

    $borderMap = @{
        'None'    = [PSCustomObject]@{ TL = '';                  T = '';                  TR = '';                  L = '';                  R = '';                  BL = '';                  B = '';                  BR = '' }
        'Normal'  = [PSCustomObject]@{ TL = [char]0x250C;        T = [char]0x2500;        TR = [char]0x2510;        L = [char]0x2502;        R = [char]0x2502;        BL = [char]0x2514;        B = [char]0x2500;        BR = [char]0x2518 }
        'Rounded' = [PSCustomObject]@{ TL = [char]0x256D;        T = [char]0x2500;        TR = [char]0x256E;        L = [char]0x2502;        R = [char]0x2502;        BL = [char]0x2570;        B = [char]0x2500;        BR = [char]0x256F }
        'Thick'   = [PSCustomObject]@{ TL = [char]0x250F;        T = [char]0x2501;        TR = [char]0x2513;        L = [char]0x2503;        R = [char]0x2503;        BL = [char]0x2517;        B = [char]0x2501;        BR = [char]0x251B }
        'Double'  = [PSCustomObject]@{ TL = [char]0x2554;        T = [char]0x2550;        TR = [char]0x2557;        L = [char]0x2551;        R = [char]0x2551;        BL = [char]0x255A;        B = [char]0x2550;        BR = [char]0x255D }
    }

    if ($borderMap.ContainsKey($Style)) {
        return $borderMap[$Style]
    }

    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
        [System.ArgumentException]::new("Unknown border style: '$Style'"),
        'InvalidBorderStyle',
        [System.Management.Automation.ErrorCategory]::InvalidArgument,
        $Style
    )
    $PSCmdlet.WriteError($errorRecord)
    return $borderMap['None']
}


