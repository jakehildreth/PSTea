function Get-ElmXtermPage {
    <#
    .SYNOPSIS
        Returns a self-contained HTML page that connects xterm.js to a WebSocket TUI server.

    .DESCRIPTION
        Generates the HTML served at GET / by Invoke-ElmWebSocketListener. The page:
          - Embeds xterm.js and xterm-addon-fit.min.js inline (no CDN, air-gap safe)
          - Creates a Terminal with convertEol:true and the given dimensions
          - Opens a WebSocket to ws://localhost:{port}/ws
          - Forwards xterm.js onData (VT sequences) over the WebSocket to the server
          - Receives ANSI strings from the server and writes them to the terminal
          - Reconnects on close (exponential backoff capped at 5s)
          - Sets a dark background matching typical TUI usage

        Requires $script:XtermJs, $script:XtermAddonFit, and $script:XtermCss to be loaded
        at module import time (set by Elm.psm1 from Private/Web/).

    .PARAMETER Port
        TCP port the WebSocket server is listening on. Used in the ws:// URL.

    .PARAMETER Title
        HTML page title. Defaults to "Elm TUI".

    .PARAMETER Cols
        Terminal width in columns. Should match -Width passed to Start-ElmWebServer.

    .PARAMETER Rows
        Terminal height in rows. Should match -Height passed to Start-ElmWebServer.

    .OUTPUTS
        string - Complete HTML document as a string.

    .EXAMPLE
        $html = Get-ElmXtermPage -Port 8080 -Cols 220 -Rows 50

    .NOTES
        JavaScript event handlers use property assignment syntax (ws.onmessage = ...) not
        method-call syntax (ws.onmessage(...)). See ADR-021.
        xterm.js v5.3.0 + xterm-addon-fit v0.8.0 bundled per ADR-022.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Port,

        [Parameter()]
        [string]$Title = 'Elm TUI',

        [Parameter()]
        [int]$Cols = 220,

        [Parameter()]
        [int]$Rows = 50
    )

    $xtermJs       = if ($script:XtermJs)       { $script:XtermJs       } else { '/* xterm.js not bundled */' }
    $xtermAddonFit = if ($script:XtermAddonFit) { $script:XtermAddonFit } else { '/* xterm-addon-fit not bundled */' }
    $xtermCss      = if ($script:XtermCss)      { $script:XtermCss      } else { '' }

    return @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$Title</title>
  <style>
    $xtermCss
    * { box-sizing: border-box; margin: 0; padding: 0; }
    html, body { width: 100%; height: 100%; background: #1e1e1e; overflow: hidden; }
    #terminal { width: 100%; height: 100%; }
    .xterm { height: 100%; }
    .xterm-viewport { overflow-y: hidden !important; }
  </style>
</head>
<body>
  <div id="terminal"></div>
  <script>
    $xtermJs
  </script>
  <script>
    $xtermAddonFit
  </script>
  <script>
    (function () {
      'use strict';

      var term = new Terminal({
        convertEol:  true,
        cols:        $Cols,
        rows:        $Rows,
        cursorBlink: true,
        theme: {
          background: '#1e1e1e',
          foreground: '#d4d4d4'
        }
      });

      var fitAddon = new FitAddon.FitAddon();
      term.loadAddon(fitAddon);
      term.open(document.getElementById('terminal'));
      fitAddon.fit();

      var ws = null;
      var reconnectDelay = 500;

      function connect() {
        ws = new WebSocket('ws://localhost:$Port/ws');

        ws.onopen = function () {
          reconnectDelay = 500;
        };

        ws.onmessage = function (e) {
          term.write(e.data);
        };

        ws.onerror = function () {
          // onclose will fire after onerror; reconnect is handled there
        };

        ws.onclose = function () {
          ws = null;
          setTimeout(connect, reconnectDelay);
          reconnectDelay = Math.min(reconnectDelay * 2, 5000);
        };
      }

      term.onData(function (data) {
        if (ws && ws.readyState === WebSocket.OPEN) {
          ws.send(data);
        }
      });

      connect();
    })();
  </script>
</body>
</html>
"@
}
