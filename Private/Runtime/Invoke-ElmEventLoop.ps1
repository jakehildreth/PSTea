function Invoke-ElmEventLoop {
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
        $viewTree     = Invoke-ElmView -ViewFn $ViewFn -Model $model
        $measuredTree = Measure-ElmViewTree -Root $viewTree -TermWidth $TerminalWidth -TermHeight $TerminalHeight
        $patches      = @(Compare-ElmViewTree -OldTree $null -NewTree $measuredTree)
        $prevTree     = $measuredTree
        if ($patches.Count -gt 0) {
            & $writeFn (ConvertTo-AnsiOutput -Root $measuredTree)
        }

        if ($null -ne $SubscriptionFn) {
            # Subscription-based path: Invoke-ElmSubscriptions is the sole queue consumer.
            # Messages are batched; a single render happens after each batch.
            $timerState = @{}
            while ($true) {
                $subs = @(& $SubscriptionFn $model)
                $msgs = @(Invoke-ElmSubscriptions -Subscriptions $subs -InputQueue $InputQueue -TimerState $timerState)

                if ($msgs.Count -eq 0) {
                    [System.Threading.Thread]::Sleep(1)
                    continue
                }

                $shouldQuit = $false
                foreach ($msg in $msgs) {
                    $updateResult = Invoke-ElmUpdate -UpdateFn $UpdateFn -Message $msg -Model $model
                    $model = $updateResult.Model
                    $cmd   = $updateResult.Cmd
                    if ($null -ne $cmd -and $cmd.Type -eq 'Quit') {
                        $shouldQuit = $true
                        break
                    }
                }

                $viewTree     = Invoke-ElmView -ViewFn $ViewFn -Model $model
                $measuredTree = Measure-ElmViewTree -Root $viewTree -TermWidth $TerminalWidth -TermHeight $TerminalHeight
                $patches      = @(Compare-ElmViewTree -OldTree $prevTree -NewTree $measuredTree)
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
                    $updateResult = Invoke-ElmUpdate -UpdateFn $UpdateFn -Message $msg -Model $model
                    $model = $updateResult.Model
                    $cmd   = $updateResult.Cmd

                    if ($null -ne $cmd -and $cmd.Type -eq 'Quit') {
                        break
                    }

                    $viewTree     = Invoke-ElmView -ViewFn $ViewFn -Model $model
                    $measuredTree = Measure-ElmViewTree -Root $viewTree -TermWidth $TerminalWidth -TermHeight $TerminalHeight
                    $patches      = @(Compare-ElmViewTree -OldTree $prevTree -NewTree $measuredTree)
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
