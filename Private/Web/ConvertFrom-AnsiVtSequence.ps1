function ConvertFrom-AnsiVtSequence {
    <#
    .SYNOPSIS
        Translates raw VT/ANSI sequences from xterm.js onData into InputQueue PSCustomObjects.

    .DESCRIPTION
        xterm.js fires onData with a raw string that may contain one or more VT sequences,
        printable characters, or control characters in a single callback. This function parses
        the entire input string and returns one PSCustomObject per logical key event, matching
        the shape produced by New-ElmTerminalDriver:

            [PSCustomObject]@{
                Type      = 'KeyDown'
                Key       = [System.ConsoleKey]
                Char      = [char]
                Modifiers = [System.ConsoleModifiers]
            }

        Resize sequences (ESC[8;rows;colst) are parsed into:
            [PSCustomObject]@{ Type = 'Resize'; Width = [int]; Height = [int] }

        These are enqueued into the InputQueue by Invoke-ElmWebSocketListener; the event loop
        ignores Resize types (resize support deferred per ADR-024).

    .PARAMETER InputString
        Raw UTF-8 string received from xterm.js onData callback. May contain multiple
        sequences in a single call (e.g. pasted text, rapid keystrokes).

    .OUTPUTS
        PSCustomObject[] - zero or more key/resize event objects.

    .EXAMPLE
        ConvertFrom-AnsiVtSequence -InputString "`e[A"
        # Returns: @{ Type='KeyDown'; Key=[ConsoleKey]::UpArrow; Char=[char]0; Modifiers=None }

    .NOTES
        Called by Invoke-ElmWebSocketListener on each WebSocket receive. See ADR-022.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$InputString
    )

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    if ([string]::IsNullOrEmpty($InputString)) {
        return $results.ToArray()
    }

    # ESC code point
    $ESC_CODE  = 0x1b
    $chars     = $InputString.ToCharArray()
    $i         = 0
    $len       = $chars.Length

    while ($i -lt $len) {
        $c     = $chars[$i]
        $cInt  = [int]$c

        if ($cInt -eq $ESC_CODE) {
            # Escape or escape sequence
            if ($i + 1 -lt $len -and [int]$chars[$i + 1] -eq 0x5B) {
                # ESC [ ... — CSI sequence
                $i += 2   # skip ESC [
                $paramBuf = [System.Text.StringBuilder]::new()
                while ($i -lt $len -and (([int]$chars[$i] -ge 0x30 -and [int]$chars[$i] -le 0x3F))) {
                    $null = $paramBuf.Append($chars[$i])
                    $i++
                }
                # final byte (command byte: A-Z a-z @)
                $finalChar = if ($i -lt $len) { $chars[$i]; $i++ } else { [char]0 }
                $param     = $paramBuf.ToString()

                $item = _ConvertFrom-AnsiCsi -Param $param -Final $finalChar
                if ($null -ne $item) { $results.Add($item) }

            } elseif ($i + 1 -lt $len) {
                # ESC <char> — Alt+char or other two-byte sequence
                $i++
                $altChar = $chars[$i]; $i++
                $altInt  = [int]$altChar
                $ck = _ConvertFrom-AnsiCharToConsoleKey -CharCode $altInt
                $results.Add([PSCustomObject]@{
                    Type      = 'KeyDown'
                    Key       = $ck.Key
                    Char      = $altChar
                    Modifiers = [System.ConsoleModifiers]::Alt
                })
            } else {
                # Bare ESC at end of string
                $i++
                $results.Add([PSCustomObject]@{
                    Type      = 'KeyDown'
                    Key       = [System.ConsoleKey]::Escape
                    Char      = [char]$ESC_CODE
                    Modifiers = [System.ConsoleModifiers]::None
                })
            }

        } elseif ($cInt -eq 0x7F) {
            # DEL / Backspace
            $i++
            $results.Add([PSCustomObject]@{
                Type      = 'KeyDown'
                Key       = [System.ConsoleKey]::Backspace
                Char      = [char]0x7F
                Modifiers = [System.ConsoleModifiers]::None
            })

        } elseif ($cInt -eq 0x0D) {
            # CR / Enter
            $i++
            $results.Add([PSCustomObject]@{
                Type      = 'KeyDown'
                Key       = [System.ConsoleKey]::Enter
                Char      = [char]0x0D
                Modifiers = [System.ConsoleModifiers]::None
            })

        } elseif ($cInt -eq 0x09) {
            # Tab
            $i++
            $results.Add([PSCustomObject]@{
                Type      = 'KeyDown'
                Key       = [System.ConsoleKey]::Tab
                Char      = [char]0x09
                Modifiers = [System.ConsoleModifiers]::None
            })

        } elseif ($cInt -ge 0x01 -and $cInt -le 0x1A) {
            # Ctrl+A (0x01) through Ctrl+Z (0x1A)
            $i++
            $letterCode  = $cInt - 1 + [int][char]'A'  # 0x01 -> A (65), etc.
            $letterChar  = [char]$letterCode
            $ck = [System.ConsoleKey]$letterCode
            $results.Add([PSCustomObject]@{
                Type      = 'KeyDown'
                Key       = $ck
                Char      = $letterChar
                Modifiers = [System.ConsoleModifiers]::Control
            })

        } elseif ($cInt -ge 0x20 -and $cInt -le 0x7E) {
            # Printable ASCII
            $i++
            $ck   = _ConvertFrom-AnsiCharToConsoleKey -CharCode $cInt
            $mods = if ($cInt -ge [int][char]'A' -and $cInt -le [int][char]'Z') {
                [System.ConsoleModifiers]::Shift
            } else {
                [System.ConsoleModifiers]::None
            }
            $results.Add([PSCustomObject]@{
                Type      = 'KeyDown'
                Key       = $ck.Key
                Char      = $c
                Modifiers = $mods
            })

        } else {
            # Unknown / unprintable — skip
            $i++
        }
    }

    return $results.ToArray()
}

# --- Private helpers (not exported) ---

function _ConvertFrom-AnsiCsi {
    # Parses a CSI sequence: param string + final byte → PSCustomObject or $null
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
        $mods    = _ConvertFrom-AnsiModCode -ModCode $modCode
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

function _ConvertFrom-AnsiModCode {
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

function _ConvertFrom-AnsiCharToConsoleKey {
    param([int]$CharCode)
    # Map ASCII code points to ConsoleKey enum values.
    # ConsoleKey enum: letter keys A-Z map to 65-90; digit keys D0-D9 map to 48+offset (96-105? No.)
    # Actually [ConsoleKey]::A = 65, [ConsoleKey]::D0 = 48, [ConsoleKey]::D1 = 49 ... D9 = 57
    # Lowercase a-z (97-122) → uppercase ConsoleKey A-Z (65-90)
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
    # Punctuation/symbols — use OemX keys where possible, else Oem1 as fallback
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
