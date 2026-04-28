function Start-TeaWebServer {
    <#
    .SYNOPSIS
        Starts a PSTea application served in a browser via WebSocket and xterm.js.

    .DESCRIPTION
        Runs a PSTea MVU application in a browser using a self-hosted HTTP/WebSocket server.

        - Binds HttpListener on http://localhost:{port}/
        - Serves a self-contained HTML page with bundled xterm.js at GET /
        - Upgrades WebSocket connections at GET /ws
        - Translates xterm.js VT input sequences into PSCustomObject input events (ADR-022)
        - Routes ANSI output from the event loop to the WebSocket send queue (ADR-021)
        - Prints "Listening on http://localhost:{Port}/ (Press Ctrl+C to stop)"
        - Does NOT open a browser automatically (user must open it manually)

        This function bypasses Start-TeaProgram to avoid PTY dimension validation,
        since no console is attached in web-serving mode (ADR-023).

        See ADR-023 for the 220×50 default dimension rationale.
        See ADR-024 for why browser resize is deferred.

    .PARAMETER InitFn
        Mandatory. Scriptblock. Called once at startup; must return { Model, Cmd }.

    .PARAMETER UpdateFn
        Mandatory. Scriptblock accepting ($msg, $model); must return { Model, Cmd }.

    .PARAMETER ViewFn
        Mandatory. Scriptblock accepting ($model); must return a view tree node.

    .PARAMETER SubscriptionFn
        Optional. Scriptblock accepting ($model); returns an array of subscription objects
        created by New-TeaKeySub and/or New-TeaTimerSub.

    .PARAMETER TickMs
        When positive, a background runspace enqueues a Tick message at this interval (ms).

    .PARAMETER Port
        TCP port for the HTTP/WebSocket server. Defaults to 8080.

    .PARAMETER Width
        Virtual terminal width in columns (no PTY, so this is passed directly).
        Defaults to 220.

    .PARAMETER Height
        Virtual terminal height in rows. Defaults to 50.

    .PARAMETER Title
        Browser tab title. Defaults to "PSTea TUI".

    .EXAMPLE
        $initFn   = { [PSCustomObject]@{ Model = @{ Count = 0 }; Cmd = $null } }
        $updateFn = {
            param($msg, $model)
            if ($msg.Key -eq 'Q') { return [PSCustomObject]@{ Model = $model; Cmd = [PSCustomObject]@{ Type = 'Quit' } } }
            [PSCustomObject]@{ Model = $model; Cmd = $null }
        }
        $viewFn   = { param($model) New-TeaText -Content "Count: $($model.Count)" }
        $params   = @{
            InitFn   = $initFn
            UpdateFn = $updateFn
            ViewFn   = $viewFn
            Port     = 8080
        }
        Start-TeaWebServer @params

    .NOTES
        Requires PowerShell 7+ on macOS/Linux.
        On Windows, HttpListener on http://localhost/ does not require netsh URL reservation.
    #>
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$InitFn,

        [Parameter(Mandatory)]
        [scriptblock]$UpdateFn,

        [Parameter(Mandatory)]
        [scriptblock]$ViewFn,

        [Parameter()]
        [AllowNull()]
        [scriptblock]$SubscriptionFn = $null,

        [Parameter()]
        [int]$TickMs = 0,

        [Parameter()]
        [int]$Port = 8080,

        [Parameter()]
        [int]$Width = 220,

        [Parameter()]
        [int]$Height = 50,

        [Parameter()]
        [string]$Title = 'PSTea TUI'
    )

    # Enable ANSI/VT processing (no-op on Linux/macOS; needed on Windows conhost)
    [void](Enable-VirtualTerminal)

    # Stop any previously-registered listener via direct .NET calls on AppDomain-stored
    # objects. This is immune to runspace disposal (PS closures become invalid when their
    # originating runspace is killed by the VS Code Extension on Ctrl+C, causing catch {}
    # to silently swallow the error and leaving the port bound).
    $prevCts      = [System.AppDomain]::CurrentDomain.GetData('PSTea.ActiveCts')
    $prevListener = [System.AppDomain]::CurrentDomain.GetData('PSTea.ActiveListener')
    $prevState    = [System.AppDomain]::CurrentDomain.GetData('PSTea.ActiveSharedState')
    $prevRs       = [System.AppDomain]::CurrentDomain.GetData('PSTea.ActiveRunspaces')
    if ($null -ne $prevState)    { try { $prevState.Stop = $true } catch {} }
    if ($null -ne $prevCts)      { try { $prevCts.Cancel() } catch {} }
    $prevWs = if ($null -ne $prevState) { $prevState.ActiveSocket } else { $null }
    if ($null -ne $prevWs)       { try { $prevWs.Abort() } catch {} }
    if ($null -ne $prevListener) { try { $prevListener.Stop(); $prevListener.Close() } catch {} }
    if ($null -ne $prevRs)       { foreach ($rs in $prevRs) { try { $rs.Dispose() } catch {} } }
    [System.AppDomain]::CurrentDomain.SetData('PSTea.ActiveListener',    $null)
    [System.AppDomain]::CurrentDomain.SetData('PSTea.ActiveCts',         $null)
    [System.AppDomain]::CurrentDomain.SetData('PSTea.ActiveSharedState', $null)
    [System.AppDomain]::CurrentDomain.SetData('PSTea.ActiveRunspaces',   $null)
    # Also clear the DriverContainer in case a normal exit had already populated it.
    $teaContainer = [System.AppDomain]::CurrentDomain.GetData('PSTea.DriverContainer')
    if ($null -ne $teaContainer) { $teaContainer.Active = $null }

    # Fail fast if port is already in use
    try {
        $testListener = [System.Net.HttpListener]::new()
        $testListener.Prefixes.Add("http://localhost:$Port/")
        $testListener.Start()
        $testListener.Stop()
        $testListener.Close()
    } catch {
        $exception = [System.InvalidOperationException]::new(
            "Port $Port is already in use. Kill the existing process or choose a different port."
        )
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            $exception,
            'PortInUse',
            [System.Management.Automation.ErrorCategory]::ResourceUnavailable,
            $Port
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    # Create the WebSocket driver (starts HttpListener + accept/send runspaces)
    # $driver is declared before the try so the finally null-guard always fires.
    $driver   = $null
    $tickLoop = $null
    try {
        $driver = New-TeaWebSocketDriver -Port $Port -Width $Width -Height $Height -Title $Title
        $teaContainer = [System.AppDomain]::CurrentDomain.GetData('PSTea.DriverContainer')
        if ($null -ne $teaContainer) { $teaContainer.Active = $driver }

        # Optional tick loop (same pattern as Start-TeaProgram)
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

        # Get initial model from InitFn
        $initResult   = & $InitFn
        $initialModel = $initResult.Model

        Write-Information "Listening on http://localhost:$Port/ (Press Ctrl+C to stop)" -InformationAction Continue

        $eventLoopParams = @{
            InitialModel   = $initialModel
            UpdateFn       = $UpdateFn
            ViewFn         = $ViewFn
            InputQueue     = $driver.InputQueue
            SubscriptionFn = $SubscriptionFn
            TerminalWidth  = $Width
            TerminalHeight = $Height
            OutputSink     = $driver.OutputSink
        }
        [void](Invoke-TeaEventLoop @eventLoopParams)
    } catch {
        $ts = [datetime]::Now.ToString('HH:mm:ss.fff')
        Add-Content -Path '/tmp/pstea-web-debug.log' -Value "[$ts][EVENTLOOP] FATAL: $_" -ErrorAction SilentlyContinue
        Add-Content -Path '/tmp/pstea-web-debug.log' -Value "[$ts][EVENTLOOP] StackTrace: $($_.ScriptStackTrace)" -ErrorAction SilentlyContinue
        throw
    } finally {
        if ($null -ne $tickLoop) {
            try { $tickLoop.PowerShell.Stop() } catch {}
            try { $tickLoop.Runspace.Close()  } catch {}
        }
        if ($null -ne $driver) { & $driver.Stop }
        [System.AppDomain]::CurrentDomain.SetData('PSTea.ActiveListener',    $null)
        [System.AppDomain]::CurrentDomain.SetData('PSTea.ActiveCts',         $null)
        [System.AppDomain]::CurrentDomain.SetData('PSTea.ActiveSharedState', $null)
        [System.AppDomain]::CurrentDomain.SetData('PSTea.ActiveRunspaces',   $null)
        $teaContainer = [System.AppDomain]::CurrentDomain.GetData('PSTea.DriverContainer')
        if ($null -ne $teaContainer) { $teaContainer.Active = $null }
    }
}

Set-Alias -Name TeaWebServer         -Value Start-TeaWebServer
