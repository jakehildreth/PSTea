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
        Start-TeaWebServer -InitFn { [PSCustomObject]@{ Model = @{ Count = 0 }; Cmd = $null } } `
            -UpdateFn { param($msg, $model)
                if ($msg.Key -eq 'Q') { return [PSCustomObject]@{ Model = $model; Cmd = [PSCustomObject]@{ Type = 'Quit' } } }
                [PSCustomObject]@{ Model = $model; Cmd = $null } } `
            -ViewFn { param($model) New-TeaText -Content "Count: $($model.Count)" } `
            -Port 8080

    .NOTES
        Requires PowerShell 7+ on macOS/Linux.
        On Windows, HttpListener on http://localhost/ does not require netsh URL reservation.
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
    $null = Enable-VirtualTerminal

    # Fail fast if port is already in use
    try {
        $testListener = [System.Net.HttpListener]::new()
        $testListener.Prefixes.Add("http://localhost:$Port/")
        $testListener.Start()
        $testListener.Stop()
        $testListener.Close()
    } catch {
        throw "Port $Port is already in use. Kill the existing process or choose a different port."
    }

    # Create the WebSocket driver (starts HttpListener + accept/send runspaces)
    $driver = New-TeaWebSocketDriver -Port $Port -Width $Width -Height $Height -Title $Title

    # Optional tick loop (same pattern as Start-TeaProgram)
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

    # Get initial model from InitFn
    $initResult   = & $InitFn
    $initialModel = $initResult.Model

    Write-Host "Listening on http://localhost:$Port/ (Press Ctrl+C to stop)"

    try {
        $null = Invoke-TeaEventLoop `
            -InitialModel   $initialModel `
            -UpdateFn       $UpdateFn `
            -ViewFn         $ViewFn `
            -InputQueue     $driver.InputQueue `
            -SubscriptionFn $SubscriptionFn `
            -TerminalWidth  $Width `
            -TerminalHeight $Height `
            -OutputSink     $driver.OutputSink
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
        & $driver.Stop
    }
}

Set-Alias -Name TeaWebServer         -Value Start-TeaWebServer
