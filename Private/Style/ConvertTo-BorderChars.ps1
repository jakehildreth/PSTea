function ConvertTo-BorderChars {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Style
    )

    $borderMap = @{
        'None'    = [PSCustomObject]@{ TL = '';  T = '';  TR = '';  L = '';  R = '';  BL = '';  B = '';  BR = '' }
        'Normal'  = [PSCustomObject]@{ TL = '┌'; T = '─'; TR = '┐'; L = '│'; R = '│'; BL = '└'; B = '─'; BR = '┘' }
        'Rounded' = [PSCustomObject]@{ TL = '╭'; T = '─'; TR = '╮'; L = '│'; R = '│'; BL = '╰'; B = '─'; BR = '╯' }
        'Thick'   = [PSCustomObject]@{ TL = '┏'; T = '━'; TR = '┓'; L = '┃'; R = '┃'; BL = '┗'; B = '━'; BR = '┛' }
        'Double'  = [PSCustomObject]@{ TL = '╔'; T = '═'; TR = '╗'; L = '║'; R = '║'; BL = '╚'; B = '═'; BR = '╝' }
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
