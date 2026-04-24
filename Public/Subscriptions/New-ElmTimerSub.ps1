function New-ElmTimerSub {
    <#
    .SYNOPSIS
        Creates a timer subscription for use in a SubscriptionFn.

    .DESCRIPTION
        Returns a subscription descriptor that fires a handler scriptblock at a
        fixed millisecond interval, producing a message for the Update function.

        Timer state (last-fired timestamp) is managed by Invoke-ElmSubscriptions
        across loop iterations. If the same IntervalMs value appears in multiple
        calls to the SubscriptionFn, the state is shared (keyed by interval).

        Timer subscriptions are only active when present in the array returned
        by SubscriptionFn. Removing a timer sub from the array pauses it; adding it
        back resets the interval clock.

    .PARAMETER IntervalMs
        Firing interval in milliseconds. Must be a positive integer.

    .PARAMETER Handler
        Scriptblock invoked when the interval elapses. Receives no arguments.
        Must return a message object or $null.

        Example: { 'Tick' }
        Example: { [PSCustomObject]@{ Type = 'Timer'; At = [datetime]::Now } }

    .OUTPUTS
        PSCustomObject with Type='Timer', IntervalMs, and Handler properties.

    .EXAMPLE
        New-ElmTimerSub -IntervalMs 1000 -Handler { 'Tick' }

    .EXAMPLE
        New-ElmTimerSub -IntervalMs 100 -Handler { [PSCustomObject]@{ Type='Frame' } }

    .NOTES
        Use inside a SubscriptionFn passed to Start-ElmProgram via -SubscriptionFn.
        For conditional timers (e.g., pause/resume), check model state inside the
        SubscriptionFn and only add the timer sub when needed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, 2147483647)]
        [int]$IntervalMs,

        [Parameter(Mandatory)]
        [scriptblock]$Handler
    )

    return [PSCustomObject]@{
        Type       = 'Timer'
        IntervalMs = $IntervalMs
        Handler    = $Handler
    }
}
