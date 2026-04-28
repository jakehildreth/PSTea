function Start-TeaProgram {
    <#
    .SYNOPSIS
        Starts a TEA (The Elm Architecture) program in the terminal.

    .DESCRIPTION
        Calls InitFn to obtain the initial model, creates a terminal driver to read
        keyboard input, runs the MVU event loop until a Quit command is returned, then
        tears down the driver and returns the final model.

        The three required scriptblocks mirror The Elm Architecture (TEA):
          - InitFn   : () -> { Model; Cmd }
          - UpdateFn : ($msg, $model) -> { Model; Cmd }
          - ViewFn   : ($model) -> view-tree node

    .PARAMETER InitFn
        Scriptblock with no parameters that returns a PSCustomObject with Model and Cmd
        properties. Cmd may be $null.

    .PARAMETER UpdateFn
        Scriptblock accepting ($msg, $model) that returns a PSCustomObject with Model
        and Cmd properties. Return Cmd.Type = 'Quit' to exit the event loop.

    .PARAMETER ViewFn
        Scriptblock accepting ($model) that returns a view-tree node (Type 'Text' or
        'Box') produced by New-TeaText, New-TeaBox, or New-TeaRow.

    .PARAMETER Width
        Terminal width in columns used for layout. Defaults to the current terminal width
        ([Console]::WindowWidth). If the terminal reports no width (e.g. no TTY), falls
        back to 80. Must not exceed the actual terminal width - if it does, a terminating
        error is thrown with instructions to resize or omit the parameter.

    .PARAMETER Height
        Terminal height in rows used for layout. Defaults to the current terminal height
        ([Console]::WindowHeight). If the terminal reports no height, falls back to 24.
        Must not exceed the actual terminal height.

    .PARAMETER SubscriptionFn
        Optional scriptblock that accepts the current model and returns an array of
        subscription objects created by New-TeaKeySub and New-TeaTimerSub.

        When provided, Invoke-TeaSubscriptions becomes the sole InputQueue consumer
        and messages are dispatched via handler scriptblocks before reaching UpdateFn.
        This enables declarative, model-dependent event routing.

        When omitted, the event loop falls back to the legacy direct-dequeue path
        where raw KeyDown events are forwarded to UpdateFn unchanged.

        Example:
            $subFn = {
                param($model)
                $subs = @(New-TeaKeySub -Key 'Q' -Handler { 'Quit' })
                if ($model.Running) {
                    $subs += New-TeaTimerSub -IntervalMs 1000 -Handler { 'Tick' }
                }
                $subs
            }

    .PARAMETER TickMs
        When set to a positive integer, creates a background timer runspace that enqueues
        a Tick message ({ Type = 'Tick'; Key = 'Tick' }) to the input queue at the given
        interval in milliseconds. Use in UpdateFn by handling $msg.Key -eq 'Tick' to
        drive time-based state changes (animations, countdowns, game loops).
        Defaults to 0 (no ticking).

    .OUTPUTS
        PSCustomObject - the final model at the time the event loop exited.

    .EXAMPLE
        $init   = { [PSCustomObject]@{ Model = [PSCustomObject]@{ Count = 0 }; Cmd = $null } }
        $update = { param($msg, $model)
            $newCount = if ($msg -eq 'Inc') { $model.Count + 1 } else { $model.Count }
            [PSCustomObject]@{ Model = [PSCustomObject]@{ Count = $newCount }; Cmd = $null }
        }
        $view   = { param($model) New-TeaText -Content "Count: $($model.Count)" }
        Start-TeaProgram -InitFn $init -UpdateFn $update -ViewFn $view

    .NOTES
        Requires a terminal that supports ANSI escape sequences. On Windows, ensure
        Enable-VirtualTerminalProcessing has been called before invoking this function.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$InitFn,

        [Parameter(Mandatory)]
        [scriptblock]$UpdateFn,

        [Parameter(Mandatory)]
        [scriptblock]$ViewFn,

        [Parameter()]
        [int]$Width = 0,

        [Parameter()]
        [int]$Height = 0,

        [Parameter()]
        [AllowNull()]
        [scriptblock]$SubscriptionFn = $null,

        [Parameter()]
        [int]$TickMs = 0
    )

    # Ensure ANSI/VT processing is active (required on Windows PS5.1/conhost; no-op elsewhere)
    $null = Enable-VirtualTerminal

    # Resolve actual terminal dimensions, falling back if running without a TTY
    $termWidth  = if ([Console]::WindowWidth  -gt 0) { [Console]::WindowWidth  } else { 80 }
    $termHeight = if ([Console]::WindowHeight -gt 0) { [Console]::WindowHeight } else { 24 }

    # Validate explicit sizes - must fit in the real terminal
    if ($PSBoundParameters.ContainsKey('Width') -and $Width -gt $termWidth) {
        $ex  = [System.ArgumentOutOfRangeException]::new(
            'Width',
            "Requested width ($Width) exceeds terminal width ($termWidth). " +
            'Resize the terminal or omit -Width to fill the terminal automatically.'
        )
        $err = [System.Management.Automation.ErrorRecord]::new(
            $ex, 'TerminalTooSmall',
            [System.Management.Automation.ErrorCategory]::InvalidArgument,
            $Width
        )
        $PSCmdlet.ThrowTerminatingError($err)
    }
    if ($PSBoundParameters.ContainsKey('Height') -and $Height -gt $termHeight) {
        $ex  = [System.ArgumentOutOfRangeException]::new(
            'Height',
            "Requested height ($Height) exceeds terminal height ($termHeight). " +
            'Resize the terminal or omit -Height to fill the terminal automatically.'
        )
        $err = [System.Management.Automation.ErrorRecord]::new(
            $ex, 'TerminalTooSmall',
            [System.Management.Automation.ErrorCategory]::InvalidArgument,
            $Height
        )
        $PSCmdlet.ThrowTerminatingError($err)
    }

    $resolvedWidth  = if ($PSBoundParameters.ContainsKey('Width'))  { $Width  } else { $termWidth  }
    $resolvedHeight = if ($PSBoundParameters.ContainsKey('Height')) { $Height } else { $termHeight }

    $driver = New-TeaTerminalDriver -AltScreen

    $tickLoop = $null
    if ($TickMs -gt 0) {
        $tickQueue    = $driver.InputQueue
        $tickInterval = $TickMs
        $tickLoop = Invoke-TeaDriverLoop -ScriptBlock {
            param($queue, $intervalMs)
            while ($true) {
                [System.Threading.Thread]::Sleep($intervalMs)
                $queue.Enqueue([PSCustomObject]@{ Type = 'Tick'; Key = 'Tick' })
            }
        } -Arguments @($tickQueue, $tickInterval)
    }

    $initResult    = & $InitFn
    $initialModel  = $initResult.Model

    try {
        $finalModel = Invoke-TeaEventLoop `
            -InitialModel   $initialModel `
            -UpdateFn       $UpdateFn `
            -ViewFn         $ViewFn `
            -InputQueue     $driver.InputQueue `
            -SubscriptionFn $SubscriptionFn `
            -TerminalWidth  $resolvedWidth `
            -TerminalHeight $resolvedHeight
    } finally {
        if ($null -ne $tickLoop) {
            try { $tickLoop.PowerShell.Stop() } catch {}
            try { $tickLoop.Runspace.Close()  } catch {}
        }
        & $driver.Stop
    }

    return $finalModel
}

Set-Alias -Name TeaProgram          -Value Start-TeaProgram
