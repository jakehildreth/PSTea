function Invoke-TeaSubscriptions {
    <#
    .SYNOPSIS
        Consumes the input queue and fires matching subscriptions, returning messages.

    .DESCRIPTION
        Sole consumer of the InputQueue in subscription-mode event loops.

        On each call:
          1. Timer subscriptions are checked against elapsed time. When an interval
             has elapsed, the handler is invoked and its return value is added to the
             output message list. Timer state (last-fired ms) is maintained in the
             caller-supplied TimerState hashtable across calls.

          2. All pending items are drained from the InputQueue. For each KeyDown event,
             matching Key subscriptions are found and their handlers invoked. Letter
             keys (A-Z) are matched case-insensitively: a 'Q' subscription fires for
             both lowercase 'q' (Modifiers=None) and uppercase 'Q' (Modifiers=Shift).

          3. Pass-through mode: when no Key subscriptions are defined, all KeyDown
             events are forwarded as raw messages so that UpdateFn-based key handling
             (used by existing demos) continues to work without modification.

          4. Legacy Tick messages (from -TickMs timer runspace) are always forwarded
             as-is for backward compatibility.

    .PARAMETER Subscriptions
        Array of subscription objects from New-TeaKeySub / New-TeaTimerSub.
        May be $null or empty, in which case pass-through mode is active.

    .PARAMETER InputQueue
        The ConcurrentQueue[PSCustomObject] from New-TeaTerminalDriver.

    .PARAMETER TimerState
        A hashtable maintained by the caller across loop iterations.
        Stores last-fired timestamps keyed by "Timer:<IntervalMs>".
        Pass the same instance on every call; Invoke-TeaSubscriptions mutates it.

    .OUTPUTS
        Object[] - zero or more message objects to dispatch to UpdateFn.
        Always returns an array (never $null).

    .EXAMPLE
        $timerState = @{}
        $subs = @(New-TeaKeySub -Key 'Q' -Handler { 'Quit' })
        $msgs = Invoke-TeaSubscriptions -Subscriptions $subs -InputQueue $queue -TimerState $timerState

    .NOTES
        Called by Invoke-TeaEventLoop on every iteration when a SubscriptionFn is set.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object[]]$Subscriptions,

        [Parameter(Mandatory)]
        [object]$InputQueue,

        [Parameter(Mandatory)]
        [hashtable]$TimerState
    )

    $msgs      = [System.Collections.Generic.List[object]]::new()
    $keySubs   = [System.Collections.Generic.List[object]]::new()
    $timerSubs = [System.Collections.Generic.List[object]]::new()
    $charSubs  = [System.Collections.Generic.List[object]]::new()

    if ($null -ne $Subscriptions) {
        foreach ($sub in $Subscriptions) {
            if ($null -eq $sub) { continue }
            if ($sub.Type -eq 'Key')   { $keySubs.Add($sub) }
            if ($sub.Type -eq 'Timer') { $timerSubs.Add($sub) }
            if ($sub.Type -eq 'Char')  { $charSubs.Add($sub) }
        }
    }

    # --- Timer subscriptions ---
    # Use Environment.TickCount for ms-precision elapsed time.
    # Stored as [int] in TimerState; difference arithmetic is safe for intervals
    # well under the ~24-day rollover period.
    $nowMs = [System.Environment]::TickCount

    foreach ($timerSub in $timerSubs) {
        $stateKey = "Timer:$($timerSub.IntervalMs)"
        if (-not $TimerState.ContainsKey($stateKey)) {
            $TimerState[$stateKey] = $nowMs
        }
        $elapsed = $nowMs - $TimerState[$stateKey]
        if ($elapsed -ge $timerSub.IntervalMs) {
            $TimerState[$stateKey] = $nowMs
            $msg = & $timerSub.Handler
            if ($null -ne $msg) {
                $msgs.Add($msg)
            }
        }
    }

    # --- Key + Char subscriptions ---
    $hasKeySubs  = $keySubs.Count -gt 0
    $hasCharSubs = $charSubs.Count -gt 0
    $shiftBit    = [int][System.ConsoleModifiers]::Shift

    $item = $null
    while ($InputQueue.TryDequeue([ref]$item)) {
        if ($item.Type -eq 'KeyDown') {
            if ($hasKeySubs -or $hasCharSubs) {
                $matched         = $false
                $itemKeyInt      = [int]$item.Key
                $itemModsInt     = [int]$item.Modifiers
                $isLetterKey     = ($itemKeyInt -ge 65 -and $itemKeyInt -le 90)

                if ($hasKeySubs) {
                    foreach ($keySub in $keySubs) {
                        $subModsInt = [int]$keySub.Modifiers
                        $compareModsInt = $itemModsInt

                        # Case-insensitive letter matching: strip Shift from the item's
                        # modifiers when the sub requests no modifiers and the key is A-Z.
                        if ($isLetterKey -and $subModsInt -eq 0) {
                            $compareModsInt = $itemModsInt -band (-bnot $shiftBit)
                        }

                        if ($item.Key -eq $keySub.ConsoleKey -and $compareModsInt -eq $subModsInt) {
                            $msg = & $keySub.Handler $item
                            if ($null -ne $msg) {
                                $msgs.Add($msg)
                            }
                            $matched = $true
                        }
                    }
                }

                # If no key sub matched, try char subs for printable characters.
                # Char subs fire only for Unicode 0x0020-0x007E (printable ASCII).
                if (-not $matched -and $hasCharSubs) {
                    $charCode = [int]$item.Char
                    if ($charCode -ge 0x20 -and $charCode -le 0x7E) {
                        foreach ($charSub in $charSubs) {
                            $msg = & $charSub.Handler $item
                            if ($null -ne $msg) {
                                $msgs.Add($msg)
                            }
                        }
                    }
                }
            } else {
                # Pass-through: no key subs or char subs - forward raw event to UpdateFn
                $msgs.Add($item)
            }
        } elseif ($item.Type -eq 'Tick') {
            # Legacy -TickMs tick: forward as-is for backward compatibility
            $msgs.Add($item)
        }
    }

    # Wrap in outer array to prevent PS pipeline from unwrapping a single element
    return $msgs.ToArray()
}


