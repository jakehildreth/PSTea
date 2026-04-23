function ConvertTo-BorderChars {
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
