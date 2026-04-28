function ConvertFrom-AnsiCsi {
    <#
    .SYNOPSIS
        Parses a CSI escape sequence into a key or resize event.

    .DESCRIPTION
        Takes the parameter string and final byte of a CSI sequence (ESC [ <param> <final>)
        and returns a PSCustomObject describing the key press or terminal resize, or $null
        if the sequence is not recognised. Called by ConvertFrom-AnsiVtSequence.

    .PARAMETER Param
        The CSI parameter string (the text between '[' and the final byte).

    .PARAMETER Final
        The final byte character of the CSI sequence (e.g. 'A', 'B', 'H').

    .OUTPUTS
        PSCustomObject with Type='KeyDown' or Type='Resize', or $null.
    #>
    [CmdletBinding()]
    param([string]$Param, [char]$Final)

    $finalInt = [int]$Final

    # Resize: ESC [ 8 ; rows ; cols t
    if ($finalInt -eq [int][char]'t' -and $Param -match '^8;(\d+);(\d+)$') {
        return [PSCustomObject]@{
            Type   = 'Resize'
            Height = [int]$Matches[1]
            Width  = [int]$Matches[2]
        }
    }

    # Modified sequences: ESC [ 1 ; <modifier> A/B/C/D/H/F
    # modifier: 2=Shift 3=Alt 5=Ctrl 6=Ctrl+Shift 7=Alt+Ctrl
    if ($Param -match '^1;(\d+)$') {
        $modCode = [int]$Matches[1]
        $mods    = ConvertFrom-AnsiModCode -ModCode $modCode
        $ck      = switch ($Final) {
            'A' { [System.ConsoleKey]::UpArrow    }
            'B' { [System.ConsoleKey]::DownArrow  }
            'C' { [System.ConsoleKey]::RightArrow }
            'D' { [System.ConsoleKey]::LeftArrow  }
            'H' { [System.ConsoleKey]::Home       }
            'F' { [System.ConsoleKey]::End        }
            default { $null }
        }
        if ($null -ne $ck) {
            return [PSCustomObject]@{
                Type      = 'KeyDown'
                Key       = $ck
                Char      = [char]0
                Modifiers = $mods
            }
        }
    }

    # Simple cursor/nav sequences (no modifier)
    if ([string]::IsNullOrEmpty($Param)) {
        $ck = switch ($Final) {
            'A' { [System.ConsoleKey]::UpArrow    }
            'B' { [System.ConsoleKey]::DownArrow  }
            'C' { [System.ConsoleKey]::RightArrow }
            'D' { [System.ConsoleKey]::LeftArrow  }
            'H' { [System.ConsoleKey]::Home       }
            'F' { [System.ConsoleKey]::End        }
            default { $null }
        }
        if ($null -ne $ck) {
            return [PSCustomObject]@{
                Type      = 'KeyDown'
                Key       = $ck
                Char      = [char]0
                Modifiers = [System.ConsoleModifiers]::None
            }
        }
    }

    # Tilde sequences: ESC [ N ~
    if ($finalInt -eq [int][char]'~') {
        $ck = switch ($Param) {
            '1'  { [System.ConsoleKey]::Home     }
            '2'  { [System.ConsoleKey]::Insert   }
            '3'  { [System.ConsoleKey]::Delete   }
            '4'  { [System.ConsoleKey]::End      }
            '5'  { [System.ConsoleKey]::PageUp   }
            '6'  { [System.ConsoleKey]::PageDown }
            '11' { [System.ConsoleKey]::F1       }
            '12' { [System.ConsoleKey]::F2       }
            '13' { [System.ConsoleKey]::F3       }
            '14' { [System.ConsoleKey]::F4       }
            '15' { [System.ConsoleKey]::F5       }
            '17' { [System.ConsoleKey]::F6       }
            '18' { [System.ConsoleKey]::F7       }
            '19' { [System.ConsoleKey]::F8       }
            '20' { [System.ConsoleKey]::F9       }
            '21' { [System.ConsoleKey]::F10      }
            '23' { [System.ConsoleKey]::F11      }
            '24' { [System.ConsoleKey]::F12      }
            default { $null }
        }
        if ($null -ne $ck) {
            return [PSCustomObject]@{
                Type      = 'KeyDown'
                Key       = $ck
                Char      = [char]0
                Modifiers = [System.ConsoleModifiers]::None
            }
        }
    }

    return $null
}
