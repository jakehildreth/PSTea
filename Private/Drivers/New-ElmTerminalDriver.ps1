function New-ElmTerminalDriver {
    [CmdletBinding()]
    param(
        [switch]$AltScreen
    )

    $esc      = [char]27
    $altEnter = $esc + '[?1049h'
    $altExit  = $esc + '[?1049l'

    # Require UTF-8 so Unicode characters (●, ○, box-drawing, etc.) render correctly.
    # Save previous encodings so the stop function can restore them cleanly.
    $prevOutputEncoding = [Console]::OutputEncoding
    $prevInputEncoding  = [Console]::InputEncoding
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding  = [System.Text.Encoding]::UTF8

    $inputQueue = [System.Collections.Concurrent.ConcurrentQueue[PSCustomObject]]::new()
    $cts = [System.Threading.CancellationTokenSource]::new()

    $readerScript = {
        param($queue, $token)
        while (-not $token.IsCancellationRequested) {
            try {
                if ([Console]::KeyAvailable) {
                    $consoleKey = [Console]::ReadKey($true)
                    $keyEvent = [PSCustomObject]@{
                        Type      = 'KeyDown'
                        Key       = $consoleKey.Key
                        Char      = $consoleKey.KeyChar
                        Modifiers = $consoleKey.Modifiers
                    }
                    $queue.Enqueue($keyEvent)
                } else {
                    [System.Threading.Thread]::Sleep(1)
                }
            } catch {
                [System.Threading.Thread]::Sleep(50)
            }
        }
    }

    $loop = Invoke-ElmDriverLoop -ScriptBlock $readerScript -Arguments @($inputQueue, $cts.Token)

    if ($AltScreen.IsPresent) {
        # Enter alternate screen buffer - hides previous terminal content for a clean TUI canvas
        [Console]::Write($altEnter)
    }

    $useAltScreen       = $AltScreen.IsPresent
    $stopFn = {
        $cts.Cancel()
        try { $loop.PowerShell.Stop() } catch {}
        try { $loop.Runspace.Close() } catch {}
        if ($useAltScreen) {
            # Restore terminal - exit alt screen so the shell prompt returns to the main buffer
            [Console]::Write($altExit)
        }
        # Restore encodings to whatever the caller had before
        [Console]::OutputEncoding = $prevOutputEncoding
        [Console]::InputEncoding  = $prevInputEncoding
    }.GetNewClosure()

    return [PSCustomObject]@{
        InputQueue = $inputQueue
        Stop       = $stopFn
        Loop       = $loop
    }
}
