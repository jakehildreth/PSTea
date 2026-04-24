function Invoke-ElmSubscriptions {
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
        Array of subscription objects from New-ElmKeySub / New-ElmTimerSub.
        May be $null or empty, in which case pass-through mode is active.

    .PARAMETER InputQueue
        The ConcurrentQueue[PSCustomObject] from New-ElmTerminalDriver.

    .PARAMETER TimerState
        A hashtable maintained by the caller across loop iterations.
        Stores last-fired timestamps keyed by "Timer:<IntervalMs>".
        Pass the same instance on every call; Invoke-ElmSubscriptions mutates it.

    .OUTPUTS
        Object[] — zero or more message objects to dispatch to UpdateFn.
        Always returns an array (never $null).

    .EXAMPLE
        $timerState = @{}
        $subs = @(New-ElmKeySub -Key 'Q' -Handler { 'Quit' })
        $msgs = Invoke-ElmSubscriptions -Subscriptions $subs -InputQueue $queue -TimerState $timerState

    .NOTES
        Called by Invoke-ElmEventLoop on every iteration when a SubscriptionFn is set.
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

    if ($null -ne $Subscriptions) {
        foreach ($sub in $Subscriptions) {
            if ($null -eq $sub) { continue }
            if ($sub.Type -eq 'Key')   { $keySubs.Add($sub) }
            if ($sub.Type -eq 'Timer') { $timerSubs.Add($sub) }
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

    # --- Key subscriptions ---
    $hasKeySubs  = $keySubs.Count -gt 0
    $shiftBit    = [int][System.ConsoleModifiers]::Shift

    $item = $null
    while ($InputQueue.TryDequeue([ref]$item)) {
        if ($item.Type -eq 'KeyDown') {
            if ($hasKeySubs) {
                $matched         = $false
                $itemKeyInt      = [int]$item.Key
                $itemModsInt     = [int]$item.Modifiers
                $isLetterKey     = ($itemKeyInt -ge 65 -and $itemKeyInt -le 90)

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

                # Unmatched key events are silently dropped when key subs are active.
                # To handle arbitrary keys, add a catch-all sub or use pass-through mode.
            } else {
                # Pass-through: no key subs defined — forward raw event to UpdateFn
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
