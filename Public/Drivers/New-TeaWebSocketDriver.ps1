function New-TeaWebSocketDriver {
    <#
    .SYNOPSIS
        Creates a Tea driver that pipes a TUI application through a WebSocket/xterm.js interface.

    .DESCRIPTION
        Sets up:
          1. A ConcurrentQueue[PSCustomObject] for input events (fed by the WebSocket receive loop).
          2. A ConcurrentQueue[string] for ANSI output (drained by the WebSocket send loop).
          3. An OutputSink scriptblock that enqueues ANSI strings for the send loop.
          4. An HttpListener + WebSocket accept loop via Invoke-TeaWebSocketListener.

        Returns a PSCustomObject with the shape expected by Invoke-TeaEventLoop:
            { InputQueue, OutputSink, Stop }

        InputQueue  - ConcurrentQueue[PSCustomObject] to pass to Invoke-TeaEventLoop -InputQueue.
        OutputSink  - scriptblock { param($s) } to pass to Invoke-TeaEventLoop -OutputSink.
        Stop        - scriptblock to call for cleanup (stops listener, send loop, etc.).

    .PARAMETER Port
        TCP port for the HttpListener. Defaults to 8080.

    .PARAMETER Width
        Terminal width in columns. Passed to Get-TeaXtermPage and used for TerminalWidth in
        Invoke-TeaEventLoop. Defaults to 220.

    .PARAMETER Height
        Terminal height in rows. Passed to Get-TeaXtermPage and used for TerminalHeight in
        Invoke-TeaEventLoop. Defaults to 50.

    .PARAMETER Title
        Browser page title. Defaults to "PSTea TUI".

    .OUTPUTS
        PSCustomObject { InputQueue, OutputSink, Stop }

    .EXAMPLE
        $driver = New-TeaWebSocketDriver -Port 8080 -Width 220 -Height 50
        $params = @{
            InitFn         = $init
            UpdateFn       = $update
            ViewFn         = $view
            InputQueue     = $driver.InputQueue
            OutputSink     = $driver.OutputSink
            TerminalWidth  = 220
            TerminalHeight = 50
        }
        Invoke-TeaEventLoop @params
        & $driver.Stop
    #>
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$Port = 8080,

        [Parameter()]
        [int]$Width = 220,

        [Parameter()]
        [int]$Height = 50,

        [Parameter()]
        [string]$Title = 'PSTea TUI'
    )

    # Input queue: WebSocket receive loop enqueues PSCustomObject events here.
    $inputQueue  = [System.Collections.Concurrent.ConcurrentQueue[PSCustomObject]]::new()

    # Output queue: OutputSink enqueues ANSI strings; send loop drains and transmits.
    $outputQueue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()

    # OutputSink for Invoke-TeaEventLoop: captures $outputQueue via closure.
    $outputSink  = { param($s) $outputQueue.Enqueue([string]$s) }.GetNewClosure()

    # Generate HTML page (uses $script:XtermJs, $script:XtermAddonFit, $script:XtermCss).
    $htmlContent = Get-TeaXtermPage -Port $Port -Cols $Width -Rows $Height -Title $Title

    # Start the HTTP/WebSocket listener (returns { Listener, SharedState, Stop }).
    $listenerParams = @{
        Port        = $Port
        InputQueue  = $inputQueue
        OutputQueue = $outputQueue
        HtmlContent = $htmlContent
    }
    $wsServer = Invoke-TeaWebSocketListener @listenerParams

    $stopFn = { & $wsServer.Stop }.GetNewClosure()

    return [PSCustomObject]@{
        InputQueue  = $inputQueue
        OutputSink  = $outputSink
        Stop        = $stopFn
    }
}

Set-Alias -Name TeaWebSocketDriver -Value New-TeaWebSocketDriver
