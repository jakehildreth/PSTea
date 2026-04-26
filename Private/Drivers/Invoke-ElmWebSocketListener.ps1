function Invoke-ElmWebSocketListener {
    <#
    .SYNOPSIS
        Runs an HttpListener that serves a TUI over WebSocket using xterm.js.

    .DESCRIPTION
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
        ConcurrentQueue[PSCustomObject] - shared with Invoke-ElmEventLoop. The receive
        runspace enqueues key/resize events here.

    .PARAMETER OutputQueue
        ConcurrentQueue[string] - shared with the OutputSink scriptblock in
        New-ElmWebSocketDriver. The send runspace dequeues and sends ANSI strings.

    .PARAMETER HtmlContent
        Pre-rendered HTML string returned for GET /. Generate via Get-ElmXtermPage.

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

    $listener = [System.Net.HttpListener]::new()
    $listener.Prefixes.Add("http://localhost:$Port/")
    $listener.Start()

    # Shared state between runspaces: active WebSocket context and stop flag.
    # Use a single-element array so runspaces can mutate via [ref]-style indexing.
    $sharedState = [hashtable]::Synchronized(@{
        Stop           = $false
        ActiveSocket   = $null
        SessionActive  = $false
    })

    # --- Receive scriptblock: called from receive runspace ---
    $receiveScript = {
        param($ws, $inputQueue, $sharedState)

        # Import the ConvertFrom-AnsiVtSequence function into this runspace.
        # The function is available because the module was imported by the parent.
        # (Runspaces created via RunspaceFactory do not inherit the caller's session state,
        #  so we need to dot-source or pass the function definition.)
        # Actually, since Invoke-ElmDriverLoop uses a plain RunspaceFactory, we must import
        # the module or pass the function. We inline a minimal copy here for reliability.
        # The actual implementation delegates to the module-loaded function.

        $utf8 = [System.Text.Encoding]::UTF8
        $bufSize = 4096
        $buf = [byte[]]::new($bufSize)
        $segment = [System.ArraySegment[byte]]::new($buf)

        try {
            while (-not $sharedState.Stop -and $ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
                $result = $null
                try {
                    $task = $ws.ReceiveAsync($segment, [System.Threading.CancellationToken]::None)
                    $task.Wait()
                    $result = $task.Result
                } catch {
                    break
                }

                if ($null -eq $result -or $result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
                    break
                }

                if ($result.Count -gt 0) {
                    $text = $utf8.GetString($buf, 0, $result.Count)

                    # Parse VT sequences into PSCustomObjects and enqueue each one.
                    # Inline the parsing logic since we may not have the full module here.
                    $items = _ParseVtFromWebSocket -InputString $text
                    foreach ($item in $items) {
                        $inputQueue.Enqueue($item)
                    }
                }
            }
        } catch {}

        $sharedState.SessionActive = $false
        $sharedState.ActiveSocket  = $null
    }

    # --- Send scriptblock: polls OutputQueue and sends via WebSocket ---
    $sendScript = {
        param($getSocket, $outputQueue, $sharedState)

        $utf8 = [System.Text.Encoding]::UTF8
        $emptyBuf = [byte[]]@()
        $closeSegment = [System.ArraySegment[byte]]::new($emptyBuf)

        try {
            while (-not $sharedState.Stop) {
                $ws = $sharedState.ActiveSocket
                if ($null -eq $ws -or $ws.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
                    [System.Threading.Thread]::Sleep(10)
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
                        # WebSocket closed while sending; outer loop will detect state change
                    }
                } else {
                    [System.Threading.Thread]::Sleep(1)
                }
            }
        } catch {}
    }

    # --- Helper: inline VT parser for use inside runspaces ---
    # This minimal parser handles the most common sequences. It is called by the
    # receive runspace which may not have access to the module's ConvertFrom-AnsiVtSequence.
    $parseVtScript = {
        function _ParseVtFromWebSocket {
            param([string]$InputString)

            $results = [System.Collections.Generic.List[PSCustomObject]]::new()
            if ([string]::IsNullOrEmpty($InputString)) { return $results.ToArray() }

            $ESC_CODE = 0x1b
            $chars    = $InputString.ToCharArray()
            $i        = 0
            $len      = $chars.Length

            while ($i -lt $len) {
                $c    = $chars[$i]
                $cInt = [int]$c

                if ($cInt -eq $ESC_CODE) {
                    if ($i + 1 -lt $len -and [int]$chars[$i + 1] -eq 0x5B) {
                        $i += 2
                        $paramBuf = [System.Text.StringBuilder]::new()
                        while ($i -lt $len -and [int]$chars[$i] -ge 0x30 -and [int]$chars[$i] -le 0x3F) {
                            $null = $paramBuf.Append($chars[$i]); $i++
                        }
                        $finalChar = if ($i -lt $len) { $chars[$i]; $i++ } else { [char]0 }
                        $param = $paramBuf.ToString()

                        # Resize: ESC[8;rows;colst
                        if ([int]$finalChar -eq [int][char]'t' -and $param -match '^8;(\d+);(\d+)$') {
                            $results.Add([PSCustomObject]@{ Type='Resize'; Height=[int]$Matches[1]; Width=[int]$Matches[2] })
                            continue
                        }

                        # Modified: ESC[1;<mod>A/B/C/D
                        $modBits = [System.ConsoleModifiers]::None
                        $useParam = $param
                        if ($param -match '^1;(\d+)$') {
                            $mc = [int]$Matches[1] - 1
                            if ($mc -band 1) { $modBits = $modBits -bor [System.ConsoleModifiers]::Shift }
                            if ($mc -band 2) { $modBits = $modBits -bor [System.ConsoleModifiers]::Alt }
                            if ($mc -band 4) { $modBits = $modBits -bor [System.ConsoleModifiers]::Control }
                            $useParam = ''
                        }

                        $ck = switch ($finalChar) {
                            'A' { if ([string]::IsNullOrEmpty($useParam)) { [System.ConsoleKey]::UpArrow    } else { $null } }
                            'B' { if ([string]::IsNullOrEmpty($useParam)) { [System.ConsoleKey]::DownArrow  } else { $null } }
                            'C' { if ([string]::IsNullOrEmpty($useParam)) { [System.ConsoleKey]::RightArrow } else { $null } }
                            'D' { if ([string]::IsNullOrEmpty($useParam)) { [System.ConsoleKey]::LeftArrow  } else { $null } }
                            'H' { if ([string]::IsNullOrEmpty($useParam)) { [System.ConsoleKey]::Home       } else { $null } }
                            'F' { if ([string]::IsNullOrEmpty($useParam)) { [System.ConsoleKey]::End        } else { $null } }
                            '~' {
                                switch ($useParam) {
                                    '1' { [System.ConsoleKey]::Home }; '2' { [System.ConsoleKey]::Insert }
                                    '3' { [System.ConsoleKey]::Delete }; '4' { [System.ConsoleKey]::End }
                                    '5' { [System.ConsoleKey]::PageUp }; '6' { [System.ConsoleKey]::PageDown }
                                    default { $null }
                                }
                            }
                            default { $null }
                        }
                        if ($null -ne $ck) {
                            $results.Add([PSCustomObject]@{ Type='KeyDown'; Key=$ck; Char=[char]0; Modifiers=$modBits })
                        }

                    } elseif ($i + 1 -lt $len) {
                        $i++
                        $altChar = $chars[$i]; $i++
                        $results.Add([PSCustomObject]@{ Type='KeyDown'; Key=[System.ConsoleKey]::Escape; Char=$altChar; Modifiers=[System.ConsoleModifiers]::Alt })
                    } else {
                        $i++
                        $results.Add([PSCustomObject]@{ Type='KeyDown'; Key=[System.ConsoleKey]::Escape; Char=[char]0x1b; Modifiers=[System.ConsoleModifiers]::None })
                    }

                } elseif ($cInt -eq 0x7F) {
                    $i++; $results.Add([PSCustomObject]@{ Type='KeyDown'; Key=[System.ConsoleKey]::Backspace; Char=[char]0x7F; Modifiers=[System.ConsoleModifiers]::None })
                } elseif ($cInt -eq 0x0D) {
                    $i++; $results.Add([PSCustomObject]@{ Type='KeyDown'; Key=[System.ConsoleKey]::Enter; Char=[char]0x0D; Modifiers=[System.ConsoleModifiers]::None })
                } elseif ($cInt -eq 0x09) {
                    $i++; $results.Add([PSCustomObject]@{ Type='KeyDown'; Key=[System.ConsoleKey]::Tab; Char=[char]0x09; Modifiers=[System.ConsoleModifiers]::None })
                } elseif ($cInt -ge 0x01 -and $cInt -le 0x1A) {
                    $i++
                    $lc = $cInt - 1 + [int][char]'A'
                    $results.Add([PSCustomObject]@{ Type='KeyDown'; Key=[System.ConsoleKey]$lc; Char=[char]$lc; Modifiers=[System.ConsoleModifiers]::Control })
                } elseif ($cInt -ge 0x20 -and $cInt -le 0x7E) {
                    $i++
                    $ck = if ($cInt -ge [int][char]'a' -and $cInt -le [int][char]'z') { [System.ConsoleKey]($cInt - 32) }
                          elseif ($cInt -ge [int][char]'A' -and $cInt -le [int][char]'Z') { [System.ConsoleKey]$cInt }
                          elseif ($cInt -ge [int][char]'0' -and $cInt -le [int][char]'9') { [System.ConsoleKey]$cInt }
                          else { [System.ConsoleKey]::Oem1 }
                    $mods = if ($cInt -ge [int][char]'A' -and $cInt -le [int][char]'Z') { [System.ConsoleModifiers]::Shift } else { [System.ConsoleModifiers]::None }
                    $results.Add([PSCustomObject]@{ Type='KeyDown'; Key=$ck; Char=$c; Modifiers=$mods })
                } else {
                    $i++
                }
            }

            return $results.ToArray()
        }
    }

    # Accept loop: runs in a background runspace, handles HTTP + WebSocket upgrade
    $acceptScript = {
        param($listener, $inputQueue, $outputQueue, $htmlContent, $sharedState, $sendScript, $receiveScript, $parseVtScript)

        # Define the inline VT parser in this runspace
        . ([scriptblock]::Create($parseVtScript.ToString()))

        $utf8 = [System.Text.Encoding]::UTF8

        $sendLoop    = $null
        $receiveLoop = $null

        try {
            while (-not $sharedState.Stop -and $listener.IsListening) {
                $ctx = $null
                try {
                    $ctxTask = $listener.GetContextAsync()
                    # Poll for context with timeout to allow checking Stop flag
                    while (-not $ctxTask.Wait(200)) {
                        if ($sharedState.Stop) { break }
                    }
                    if ($sharedState.Stop) { break }
                    $ctx = $ctxTask.Result
                } catch {
                    if ($sharedState.Stop) { break }
                    [System.Threading.Thread]::Sleep(50)
                    continue
                }

                if ($ctx.Request.IsWebSocketRequest) {
                    # WebSocket upgrade request
                    if ($sharedState.SessionActive) {
                        # 409: session already active
                        $body  = $utf8.GetBytes('A session is already active. Close the existing tab and refresh.')
                        $ctx.Response.StatusCode  = 409
                        $ctx.Response.ContentType = 'text/plain'
                        $ctx.Response.ContentLength64 = $body.Length
                        $ctx.Response.OutputStream.Write($body, 0, $body.Length)
                        $ctx.Response.Close()
                    } else {
                        $sharedState.SessionActive = $true
                        try {
                            $wsCtxTask = $ctx.AcceptWebSocketAsync('elm-tui')
                            $wsCtxTask.Wait()
                            $wsCtx = $wsCtxTask.Result
                            $ws    = $wsCtx.WebSocket
                            $sharedState.ActiveSocket = $ws

                            # Start receive runspace
                            $recvRs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
                            $recvRs.Open()
                            $recvPs = [System.Management.Automation.PowerShell]::Create()
                            $recvPs.Runspace = $recvRs
                            [void]$recvPs.AddScript(". { $parseVtScript }; $receiveScript")
                            [void]$recvPs.AddArgument($ws)
                            [void]$recvPs.AddArgument($inputQueue)
                            [void]$recvPs.AddArgument($sharedState)
                            $receiveLoop = @{ PS = $recvPs; RS = $recvRs; AR = $recvPs.BeginInvoke() }

                        } catch {
                            $sharedState.SessionActive = $false
                            $sharedState.ActiveSocket  = $null
                        }
                    }
                } else {
                    # Regular HTTP request: serve the HTML page
                    try {
                        $body = $utf8.GetBytes($htmlContent)
                        $ctx.Response.StatusCode  = 200
                        $ctx.Response.ContentType = 'text/html; charset=utf-8'
                        $ctx.Response.ContentLength64 = $body.Length
                        $ctx.Response.Headers.Add('Cache-Control', 'no-store, no-cache, must-revalidate')
                        $ctx.Response.OutputStream.Write($body, 0, $body.Length)
                        $ctx.Response.Close()
                    } catch {}
                }
            }
        } catch {}

        # Cleanup receive loop if running
        if ($null -ne $receiveLoop) {
            try { $receiveLoop.PS.Stop() } catch {}
            try { $receiveLoop.RS.Close() } catch {}
        }
    }

    # Start the send loop (runs continuously, polls OutputQueue)
    $sendRs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $sendRs.Open()
    $sendPs = [System.Management.Automation.PowerShell]::Create()
    $sendPs.Runspace = $sendRs
    [void]$sendPs.AddScript($sendScript)
    [void]$sendPs.AddArgument($null)         # getSocket (unused; uses sharedState.ActiveSocket)
    [void]$sendPs.AddArgument($OutputQueue)
    [void]$sendPs.AddArgument($sharedState)
    $sendAr = $sendPs.BeginInvoke()

    # Start the accept loop
    $acceptRs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $acceptRs.Open()
    $acceptPs = [System.Management.Automation.PowerShell]::Create()
    $acceptPs.Runspace = $acceptRs
    [void]$acceptPs.AddScript($acceptScript)
    [void]$acceptPs.AddArgument($listener)
    [void]$acceptPs.AddArgument($InputQueue)
    [void]$acceptPs.AddArgument($OutputQueue)
    [void]$acceptPs.AddArgument($HtmlContent)
    [void]$acceptPs.AddArgument($sharedState)
    [void]$acceptPs.AddArgument($sendScript)
    [void]$acceptPs.AddArgument($receiveScript)
    [void]$acceptPs.AddArgument($parseVtScript)
    $acceptAr = $acceptPs.BeginInvoke()

    $stopFn = {
        $sharedState.Stop = $true

        # Close active WebSocket if any
        $ws = $sharedState.ActiveSocket
        if ($null -ne $ws -and $ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
            try {
                $closeTask = $ws.CloseAsync(
                    [System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure,
                    'Server stopping',
                    [System.Threading.CancellationToken]::None
                )
                $closeTask.Wait(2000) | Out-Null
            } catch {}
        }

        try { $acceptPs.Stop() } catch {}
        try { $acceptRs.Close() } catch {}
        try { $sendPs.Stop()   } catch {}
        try { $sendRs.Close()  } catch {}
        try { $listener.Stop() } catch {}
        try { $listener.Close() } catch {}
    }.GetNewClosure()

    return [PSCustomObject]@{
        Listener    = $listener
        SharedState = $sharedState
        Stop        = $stopFn
    }
}
