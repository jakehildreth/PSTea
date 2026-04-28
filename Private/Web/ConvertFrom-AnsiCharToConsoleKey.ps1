function ConvertFrom-AnsiCharToConsoleKey {
    <#
    .SYNOPSIS
        Maps an ASCII code point to a ConsoleKey enum value.

    .DESCRIPTION
        Handles lowercase and uppercase letters, digits, and common punctuation/symbols.
        Returns a PSCustomObject with a Key property. Used by ConvertFrom-AnsiVtSequence
        to convert printable characters received from xterm.js into key events.

    .PARAMETER CharCode
        The ASCII code point of the character (e.g. 65 for 'A', 97 for 'a').

    .OUTPUTS
        PSCustomObject with a Key property of type [System.ConsoleKey].
    #>
    [CmdletBinding()]
    param([int]$CharCode)
    # Map ASCII code points to ConsoleKey enum values.
    # ConsoleKey enum: letter keys A-Z map to 65-90; digit keys D0-D9 map to 48+offset (96-105? No.)
    # Actually [ConsoleKey]::A = 65, [ConsoleKey]::D0 = 48, [ConsoleKey]::D1 = 49 ... D9 = 57
    # Lowercase a-z (97-122) -> uppercase ConsoleKey A-Z (65-90)
    if ($CharCode -ge [int][char]'a' -and $CharCode -le [int][char]'z') {
        $upperCode = $CharCode - 32
        return [PSCustomObject]@{ Key = [System.ConsoleKey]$upperCode }
    }
    if ($CharCode -ge [int][char]'A' -and $CharCode -le [int][char]'Z') {
        return [PSCustomObject]@{ Key = [System.ConsoleKey]$CharCode }
    }
    if ($CharCode -ge [int][char]'0' -and $CharCode -le [int][char]'9') {
        # ConsoleKey D0 = 48, D1 = 49, ... D9 = 57
        return [PSCustomObject]@{ Key = [System.ConsoleKey]$CharCode }
    }
    # Punctuation/symbols - use OemX keys where possible, else Oem1 as fallback
    $ck = switch ($CharCode) {
        0x20 { [System.ConsoleKey]::Spacebar     }
        0x21 { [System.ConsoleKey]::D1           }  # !
        0x2E { [System.ConsoleKey]::OemPeriod    }  # .
        0x2C { [System.ConsoleKey]::OemComma     }  # ,
        0x2F { [System.ConsoleKey]::Divide       }  # /
        0x3B { [System.ConsoleKey]::Oem1         }  # ;
        0x27 { [System.ConsoleKey]::Oem7         }  # '
        0x5B { [System.ConsoleKey]::Oem4         }  # [
        0x5D { [System.ConsoleKey]::Oem6         }  # ]
        0x5C { [System.ConsoleKey]::Oem5         }  # \
        0x60 { [System.ConsoleKey]::Oem3         }  # `
        0x2D { [System.ConsoleKey]::OemMinus     }  # -
        0x3D { [System.ConsoleKey]::OemPlus      }  # =
        default { [System.ConsoleKey]::Oem1 }
    }
    return [PSCustomObject]@{ Key = $ck }
}
