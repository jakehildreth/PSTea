function Invoke-TeaEventLoop {
    <#
    .SYNOPSIS
        Runs the main TEA (The Elm Architecture) event loop.

    .DESCRIPTION
        Accepts an initial model, Update and View scriptblocks, and an InputQueue. On each
        iteration, dequeues a message, calls Update to produce a new model, calls View to
        produce a new view tree, diffs it against the previous tree, and writes ANSI output.
        Continues until Update returns a Cmd with Type='Quit'. Supports an optional
        SubscriptionFn for timer and key-subscription-based routing, and an OutputSink for
        the web driver.

    .PARAMETER InitialModel
        The model object returned by the Init scriptblock.

    .PARAMETER UpdateFn
        The Update scriptblock: param($msg, $model) -> PSCustomObject with Model and Cmd.

    .PARAMETER ViewFn
        The View scriptblock: param($model) -> view tree node.

    .PARAMETER InputQueue
        ConcurrentQueue[PSCustomObject] shared with the driver's input reader.

    .PARAMETER SubscriptionFn
        Optional. Scriptblock returning an array of subscription objects for the current model.

    .PARAMETER TerminalWidth
        Terminal width in columns. Defaults to 80.

    .PARAMETER TerminalHeight
        Terminal height in rows. Defaults to 24.

    .PARAMETER OutputSink
        Optional. Scriptblock that receives each ANSI string for output. Defaults to
        [Console]::Write.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$InitialModel,

        [Parameter(Mandatory)]
        [scriptblock]$UpdateFn,

        [Parameter(Mandatory)]
        [scriptblock]$ViewFn,

        [Parameter(Mandatory)]
        [object]$InputQueue,

        [Parameter()]
        [AllowNull()]
        [scriptblock]$SubscriptionFn = $null,

        [Parameter()]
        [int]$TerminalWidth = 80,

        [Parameter()]
        [int]$TerminalHeight = 24,

        [Parameter()]
        [AllowNull()]
        [scriptblock]$OutputSink = $null
    )

    $esc        = [char]27
    $hideCursor = $esc + '[?25l'
    $showCursor = $esc + '[?25h'

    # Route all ANSI output through OutputSink when set; fall back to Console::Write otherwise.
    $writeFn = if ($null -ne $OutputSink) { $OutputSink } else { { param($s) [Console]::Write($s) } }

    $model    = $InitialModel
    $prevTree = $null

    & $writeFn $hideCursor
    try {
        # Initial render before any messages arrive
        $viewTree     = Invoke-TeaView -ViewFn $ViewFn -Model $model
        $measuredTree = Measure-TeaViewTree -Root $viewTree -TermWidth $TerminalWidth -TermHeight $TerminalHeight
        $patches      = @(Compare-TeaViewTree -OldTree $null -NewTree $measuredTree)
        $prevTree     = $measuredTree
        if ($patches.Count -gt 0) {
            & $writeFn (ConvertTo-AnsiOutput -Root $measuredTree)
        }

        if ($null -ne $SubscriptionFn) {
            # Subscription-based path: Invoke-TeaSubscriptions is the sole queue consumer.
            # Messages are batched; a single render happens after each batch.
            $timerState = @{}
            while ($true) {
                $subs = @(& $SubscriptionFn $model)
                $msgs = @(Invoke-TeaSubscriptions -Subscriptions $subs -InputQueue $InputQueue -TimerState $timerState)

                if ($msgs.Count -eq 0) {
                    [System.Threading.Thread]::Sleep(1)
                    continue
                }

                $shouldQuit = $false
                foreach ($msg in $msgs) {
                    $updateResult = Invoke-TeaUpdate -UpdateFn $UpdateFn -Message $msg -Model $model
                    $model = $updateResult.Model
                    $cmd   = $updateResult.Cmd
                    if ($null -ne $cmd -and $cmd.Type -eq 'Quit') {
                        $shouldQuit = $true
                        break
                    }
                }

                $viewTree     = Invoke-TeaView -ViewFn $ViewFn -Model $model
                $measuredTree = Measure-TeaViewTree -Root $viewTree -TermWidth $TerminalWidth -TermHeight $TerminalHeight
                $patches      = @(Compare-TeaViewTree -OldTree $prevTree -NewTree $measuredTree)
                $prevTree     = $measuredTree

                if ($patches.Count -gt 0) {
                    if ($patches[0].Type -eq 'FullRedraw') {
                        & $writeFn (ConvertTo-AnsiOutput -Root $measuredTree)
                    } else {
                        & $writeFn (ConvertTo-AnsiPatch -Patches $patches)
                    }
                }

                if ($shouldQuit) { break }
            }
        } else {
            # Legacy path: direct queue dequeue, raw messages forwarded to UpdateFn.
            while ($true) {
                $msg = $null
                if ($InputQueue.TryDequeue([ref]$msg)) {
                    $updateResult = Invoke-TeaUpdate -UpdateFn $UpdateFn -Message $msg -Model $model
                    $model = $updateResult.Model
                    $cmd   = $updateResult.Cmd

                    if ($null -ne $cmd -and $cmd.Type -eq 'Quit') {
                        break
                    }

                    $viewTree     = Invoke-TeaView -ViewFn $ViewFn -Model $model
                    $measuredTree = Measure-TeaViewTree -Root $viewTree -TermWidth $TerminalWidth -TermHeight $TerminalHeight
                    $patches      = @(Compare-TeaViewTree -OldTree $prevTree -NewTree $measuredTree)
                    $prevTree     = $measuredTree

                    if ($patches.Count -gt 0) {
                        if ($patches[0].Type -eq 'FullRedraw') {
                            $ansiOutput = ConvertTo-AnsiOutput -Root $measuredTree
                        } else {
                            $ansiOutput = ConvertTo-AnsiPatch -Patches $patches
                        }
                        & $writeFn $ansiOutput
                    }
                } else {
                    [System.Threading.Thread]::Sleep(1)
                }
            }
        }
    } finally {
        & $writeFn $showCursor
    }

    return $model
}


