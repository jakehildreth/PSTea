# Debug log path — tee everything significant so failures in background runspaces are visible.
$script:TeaWebDebugLog = '/tmp/pstea-web-debug.log'

function Write-TeaWebDebug {
    param([string]$Message)
    $ts = [datetime]::Now.ToString('HH:mm:ss.fff')
    Add-Content -Path $script:TeaWebDebugLog -Value "[$ts] $Message" -ErrorAction SilentlyContinue
}

function Invoke-TeaWebSocketListener {
    <#
    .SYNOPSIS
        Runs an HttpListener that serves a TUI over WebSocket using xterm.js.

    .DESCRIPTION
        Simplified two-runspace design:

        Accept+Receive runspace:
          Serves the HTML page, accepts WebSocket upgrade, then receives inline
          (no nested runspace). After the socket closes, loops back to accept the
          next connection.

        Send runspace:
          Polls OutputQueue. When a socket is active, drains the queue and sends
          each item as a UTF-8 text frame. Items queued before connection are held.

        Debug output is appended to /tmp/pstea-web-debug.log.

        Creates a System.Net.HttpListener on http://localhost:{port}/.

        HTTP requests are handled in a background runspace (the accept loop). For each
        context:
          - Non-WebSocket GET requests: serve the HTML page with no-cache headers.
          - WebSocket upgrade requests:
            - If no session is active: accept the WebSocket, start receive/send runspaces.
            - If a session is already active: return 409 Conflict.

        The receive runspace reads UTF-8 frames from the WebSocket, passes them through
        ConvertFrom-AnsiVtSequence, and enqueues the resulting PSCustomObjects to
        InputQueue.

        The send runspace polls OutputQueue (ConcurrentQueue[string]) and sends each
        string as a UTF-8 WebSocket text frame.

        On WebSocket close, the active-session flag is reset and reconnect is allowed.

        Returns a PSCustomObject with { Listener, AcceptLoop, Stop } so the caller can
        clean up. Stop is a scriptblock that cancels all runspaces and closes the listener.

    .PARAMETER Port
        TCP port to listen on.

    .PARAMETER InputQueue
        ConcurrentQueue[PSCustomObject] - shared with Invoke-TeaEventLoop. The receive
        runspace enqueues key/resize events here.

    .PARAMETER OutputQueue
        ConcurrentQueue[string] - shared with the OutputSink scriptblock in
        New-TeaWebSocketDriver. The send runspace dequeues and sends ANSI strings.

    .PARAMETER HtmlContent
        Pre-rendered HTML string returned for GET /. Generate via Get-TeaXtermPage.

    .NOTES
        HttpListener works on macOS/Linux/Windows without netsh (PS7+, .NET Core).
        Single-connection model per ADR-014. See also ADR-021 (OutputSink) and ADR-022.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Port,

        [Parameter(Mandatory)]
        [object]$InputQueue,

        [Parameter(Mandatory)]
        [object]$OutputQueue,

        [Parameter(Mandatory)]
        [string]$HtmlContent
    )

    # Clear previous debug log
    try { Remove-Item -Path $script:TeaWebDebugLog -Force -ErrorAction SilentlyContinue } catch {}
    Write-TeaWebDebug "Invoke-TeaWebSocketListener starting on port $Port"

    $listener = [System.Net.HttpListener]::new()
    $listener.Prefixes.Add("http://localhost:$Port/")
    $listener.Start()
    Write-TeaWebDebug "HttpListener started"

    # Shared mutable state visible to both runspaces (same-process = same object reference).
    $sharedState = [hashtable]::Synchronized(@{
        Stop          = $false
        ActiveSocket  = $null
        SessionActive = $false
    })

    # Path to the VT parser — dot-sourced inside the accept runspace.
    # $PSScriptRoot here is Private/Drivers/; parser lives in Private/Web/
    $vtParserPath = Join-Path $PSScriptRoot '../Web/ConvertFrom-AnsiVtSequence.ps1'
    Write-TeaWebDebug "VT parser path: $vtParserPath (exists=$(Test-Path $vtParserPath))"

    # -----------------------------------------------------------------------
    # SEND RUNSPACE
    # Polls OutputQueue. When a WebSocket is active (State=Open), drains the
    # queue and sends each item as a UTF-8 text frame. Items queued before any
    # connection stay buffered until the first socket is ready.
    # -----------------------------------------------------------------------
    $sendRs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $sendRs.Open()
    $sendPs = [System.Management.Automation.PowerShell]::Create()
    $sendPs.Runspace = $sendRs
    [void]$sendPs.AddScript({
        param($outputQueue, $sharedState, $logFile)

        function dbg { param($m)
            $ts = [datetime]::Now.ToString('HH:mm:ss.fff')
            Add-Content -Path $logFile -Value "[$ts][SEND] $m" -EA SilentlyContinue
        }

        $utf8 = [System.Text.Encoding]::UTF8
        dbg 'Send loop started'
        try {
            while (-not $sharedState.Stop) {
                $ws = $sharedState.ActiveSocket
                if ($null -eq $ws -or $ws.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
                    [System.Threading.Thread]::Sleep(5)
                    continue
                }

                $item = $null
                if ($outputQueue.TryDequeue([ref]$item)) {
                    try {
                        $bytes   = $utf8.GetBytes([string]$item)
                        $segment = [System.ArraySegment[byte]]::new($bytes)
                        $task    = $ws.SendAsync(
                            $segment,
                            [System.Net.WebSockets.WebSocketMessageType]::Text,
                            $true,
                            [System.Threading.CancellationToken]::None
                        )
                        $task.Wait()
                    } catch {
                        dbg "SendAsync error: $_"
                    }
                } else {
                    [System.Threading.Thread]::Sleep(1)
                }
            }
        } catch {
            dbg "FATAL: $_"
        }
        dbg 'Send loop exited'
    })
    [void]$sendPs.AddArgument($OutputQueue)
    [void]$sendPs.AddArgument($sharedState)
    [void]$sendPs.AddArgument($script:TeaWebDebugLog)
    $sendAr = $sendPs.BeginInvoke()
    Write-TeaWebDebug "Send runspace started"

    # -----------------------------------------------------------------------
    # ACCEPT + RECEIVE RUNSPACE
    # Handles HTTP requests and WebSocket sessions in a single runspace.
    # After accepting a WebSocket, receives inline (no nested runspace) until
    # the socket closes, then loops back to accept the next connection.
    # -----------------------------------------------------------------------
    $acceptRs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $acceptRs.Open()
    $acceptPs = [System.Management.Automation.PowerShell]::Create()
    $acceptPs.Runspace = $acceptRs
    [void]$acceptPs.AddScript({
        param($listener, $inputQueue, $htmlBytes, $sharedState, $vtParserPath, $logFile)

        function dbg { param($m)
            $ts = [datetime]::Now.ToString('HH:mm:ss.fff')
            Add-Content -Path $logFile -Value "[$ts][ACCEPT] $m" -EA SilentlyContinue
        }

        # Load VT sequence parser into this runspace via dot-source
        try {
            . $vtParserPath
            dbg "VT parser loaded from $vtParserPath"
        } catch {
            dbg "Failed to load VT parser from '$vtParserPath': $_"
            # Fallback: pass bytes through as-is (no key parsing, but loop stays alive)
            function ConvertFrom-AnsiVtSequence { param([string]$InputString); return @() }
        }

        $utf8 = [System.Text.Encoding]::UTF8
        dbg 'Accept loop started'

        while (-not $sharedState.Stop -and $listener.IsListening) {

            # ---- Wait for the next HTTP context ----
            $ctx = $null
            try {
                $ctxTask = $listener.GetContextAsync()
                while (-not $ctxTask.Wait(200)) {
                    if ($sharedState.Stop) { break }
                }
                if ($sharedState.Stop) { break }
                $ctx = $ctxTask.Result
            } catch {
                if ($sharedState.Stop) { break }
                dbg "GetContextAsync error: $_"
                [System.Threading.Thread]::Sleep(50)
                continue
            }

            $isWS = $ctx.Request.IsWebSocketRequest
            $path = $ctx.Request.Url.AbsolutePath
            dbg "Request: $path IsWS=$isWS"

            if ($isWS) {
                # ---- WebSocket upgrade ----
                if ($sharedState.SessionActive) {
                    $body = $utf8.GetBytes('A session is already active. Close the other tab and refresh.')
                    $ctx.Response.StatusCode      = 409
                    $ctx.Response.ContentType     = 'text/plain'
                    $ctx.Response.ContentLength64 = $body.Length
                    try { $ctx.Response.OutputStream.Write($body, 0, $body.Length); $ctx.Response.Close() } catch {}
                    dbg '409 - session already active'
                    continue
                }

                $sharedState.SessionActive = $true
                try {
                    dbg 'Calling AcceptWebSocketAsync...'
                    $wsTask = $ctx.AcceptWebSocketAsync([NullString]::Value)
                    $wsTask.Wait()
                    $ws = $wsTask.Result.WebSocket
                    $sharedState.ActiveSocket = $ws
                    dbg "WebSocket accepted. State=$($ws.State)"

                    # ---- Inline receive loop (no nested runspace) ----
                    $buf = [byte[]]::new(8192)
                    $seg = [System.ArraySegment[byte]]::new($buf)

                    while (-not $sharedState.Stop -and
                           $ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
                        $recvTask = $null
                        try {
                            $recvTask = $ws.ReceiveAsync($seg, [System.Threading.CancellationToken]::None)
                            $recvTask.Wait()
                        } catch {
                            dbg "ReceiveAsync error: $_"
                            break
                        }

                        $r = $recvTask.Result
                        if ($r.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
                            dbg 'Received Close frame'
                            break
                        }

                        if ($r.Count -gt 0) {
                            $text = $utf8.GetString($buf, 0, $r.Count)
                            dbg "Recv $($r.Count)b: $(($text -replace '[\x00-\x1f]', '.'))"
                            $items = ConvertFrom-AnsiVtSequence -InputString $text
                            foreach ($item in $items) { $inputQueue.Enqueue($item) }
                        }
                    }
                } catch {
                    dbg "WebSocket session error: $_"
                } finally {
                    $sharedState.ActiveSocket  = $null
                    $sharedState.SessionActive = $false
                    dbg 'WebSocket session ended'
                }

            } else {
                # ---- Serve HTML page ----
                try {
                    $ctx.Response.StatusCode      = 200
                    $ctx.Response.ContentType     = 'text/html; charset=utf-8'
                    $ctx.Response.ContentLength64 = $htmlBytes.Length
                    $ctx.Response.Headers.Add('Cache-Control', 'no-store, no-cache, must-revalidate')
                    $ctx.Response.OutputStream.Write($htmlBytes, 0, $htmlBytes.Length)
                    $ctx.Response.Close()
                    dbg 'HTML served'
                } catch {
                    dbg "HTML serve error: $_"
                }
            }
        }

        dbg 'Accept loop exited'
    })
    [void]$acceptPs.AddArgument($listener)
    [void]$acceptPs.AddArgument($InputQueue)
    [void]$acceptPs.AddArgument([System.Text.Encoding]::UTF8.GetBytes($HtmlContent))
    [void]$acceptPs.AddArgument($sharedState)
    [void]$acceptPs.AddArgument($vtParserPath)
    [void]$acceptPs.AddArgument($script:TeaWebDebugLog)
    $acceptAr = $acceptPs.BeginInvoke()
    Write-TeaWebDebug "Accept runspace started"

    # Stop scriptblock — shuts everything down cleanly
    $stopFn = {
        $ts = [datetime]::Now.ToString('HH:mm:ss.fff'); Add-Content -Path $script:TeaWebDebugLog -Value "[$ts][STOP] Stop called" -ErrorAction SilentlyContinue
        $sharedState.Stop = $true

        $ws = $sharedState.ActiveSocket
        if ($null -ne $ws -and $ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
            try {
                $t = $ws.CloseAsync(
                    [System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure,
                    'Server stopping',
                    [System.Threading.CancellationToken]::None
                )
                $t.Wait(2000) | Out-Null
            } catch {}
        }

        try { $acceptPs.Stop() } catch {}
        try { $acceptRs.Close() } catch {}
        try { $sendPs.Stop()   } catch {}
        try { $sendRs.Close()  } catch {}
        try { $listener.Stop() } catch {}
        try { $listener.Close() } catch {}
        $ts = [datetime]::Now.ToString('HH:mm:ss.fff'); Add-Content -Path $script:TeaWebDebugLog -Value "[$ts][STOP] Stop complete" -ErrorAction SilentlyContinue
    }.GetNewClosure()

    return [PSCustomObject]@{
        Listener    = $listener
        SharedState = $sharedState
        Stop        = $stopFn
    }
}



