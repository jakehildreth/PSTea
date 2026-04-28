function ConvertFrom-AnsiModCode {
    <#
    .SYNOPSIS
        Converts an xterm modifier code to a ConsoleModifiers bitmask.

    .DESCRIPTION
        xterm encodes modifier keys as a 1-based bitmask: value = (Shift|Alt|Ctrl bits) + 1.
        Bit 0 = Shift, bit 1 = Alt, bit 2 = Ctrl. Decodes to [System.ConsoleModifiers] flags.

    .PARAMETER ModCode
        The xterm modifier code integer (e.g. 2=Shift, 3=Alt, 5=Ctrl, 6=Ctrl+Shift).

    .OUTPUTS
        [System.ConsoleModifiers]
    #>
    [CmdletBinding()]
    param([int]$ModCode)
    # xterm modifier encoding: value = modifier_bitmask + 1
    # bit 0 = Shift, bit 1 = Alt, bit 2 = Ctrl
    $bits = $ModCode - 1
    $mods = [System.ConsoleModifiers]::None
    if ($bits -band 1) { $mods = $mods -bor [System.ConsoleModifiers]::Shift   }
    if ($bits -band 2) { $mods = $mods -bor [System.ConsoleModifiers]::Alt     }
    if ($bits -band 4) { $mods = $mods -bor [System.ConsoleModifiers]::Control }
    return $mods
}
