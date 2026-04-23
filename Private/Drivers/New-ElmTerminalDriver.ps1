function New-ElmTerminalDriver {
    [CmdletBinding()]
    param()

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
                    [System.Threading.Thread]::Sleep(10)
                }
            } catch {
                [System.Threading.Thread]::Sleep(50)
            }
        }
    }

    $loop = Invoke-ElmDriverLoop -ScriptBlock $readerScript -Arguments @($inputQueue, $cts.Token)

    $stopFn = {
        $cts.Cancel()
        try { $loop.PowerShell.Stop() } catch {}
        try { $loop.Runspace.Close() } catch {}
    }.GetNewClosure()

    return [PSCustomObject]@{
        InputQueue = $inputQueue
        Stop       = $stopFn
        Loop       = $loop
    }
}
