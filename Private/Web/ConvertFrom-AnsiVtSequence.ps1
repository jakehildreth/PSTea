function ConvertFrom-AnsiVtSequence {
    <#
    .SYNOPSIS
        Translates raw VT/ANSI sequences from xterm.js onData into InputQueue PSCustomObjects.

    .DESCRIPTION
        xterm.js fires onData with a raw string that may contain one or more VT sequences,
        printable characters, or control characters in a single callback. This function parses
        the entire input string and returns one PSCustomObject per logical key event, matching
        the shape produced by New-TeaTerminalDriver:

            [PSCustomObject]@{
                Type      = 'KeyDown'
                Key       = [System.ConsoleKey]
                Char      = [char]
                Modifiers = [System.ConsoleModifiers]
            }

        Resize sequences (ESC[8;rows;colst) are parsed into:
            [PSCustomObject]@{ Type = 'Resize'; Width = [int]; Height = [int] }

        These are enqueued into the InputQueue by Invoke-TeaWebSocketListener; the event loop
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
        Called by Invoke-TeaWebSocketListener on each WebSocket receive. See ADR-022.
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

                $item = ConvertFrom-AnsiCsi -Param $param -Final $finalChar
                if ($null -ne $item) { $results.Add($item) }

            } elseif ($i + 1 -lt $len) {
                # ESC <char> — Alt+char or other two-byte sequence
                $i++
                $altChar = $chars[$i]; $i++
                $altInt  = [int]$altChar
                $ck = ConvertFrom-AnsiCharToConsoleKey -CharCode $altInt
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
            $ck   = ConvertFrom-AnsiCharToConsoleKey -CharCode $cInt
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