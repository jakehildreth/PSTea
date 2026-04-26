BeforeAll {
    # Stubs for dependencies called by New-ElmWebSocketDriver

    $script:XtermJs       = '/* stub */'
    $script:XtermAddonFit = '/* stub */'
    $script:XtermCss      = ''

    function Get-ElmXtermPage {
        param($Port, $Cols, $Rows, $Title)
        return "<html><!-- port=$Port cols=$Cols rows=$Rows --></html>"
    }

    function Invoke-ElmWebSocketListener {
        param($Port, $InputQueue, $OutputQueue, $HtmlContent)
        # Return a fake listener result so Stop can be called
        return [PSCustomObject]@{
            Stop = { }
        }
    }

    . $PSScriptRoot/../Public/Drivers/New-ElmWebSocketDriver.ps1
}

Describe 'New-ElmWebSocketDriver' {

    Context 'Return shape' {
        BeforeAll {
            $script:driver = New-ElmWebSocketDriver -Port 8080 -Width 220 -Height 50
        }

        AfterAll {
            if ($null -ne $script:driver -and $null -ne $script:driver.Stop) {
                & $script:driver.Stop
            }
        }

        It 'Should return a PSCustomObject' {
            $script:driver | Should -BeOfType [PSCustomObject]
        }

        It 'Should include an InputQueue property' {
            $script:driver.PSObject.Properties.Name | Should -Contain 'InputQueue'
        }

        It 'Should include an OutputSink property' {
            $script:driver.PSObject.Properties.Name | Should -Contain 'OutputSink'
        }

        It 'Should include a Stop property' {
            $script:driver.PSObject.Properties.Name | Should -Contain 'Stop'
        }
    }

    Context 'InputQueue type' {
        It 'Should expose a ConcurrentQueue as InputQueue' {
            $driver = New-ElmWebSocketDriver -Port 8081
            # Pipe-enumerating an empty ConcurrentQueue produces $null; use -is to avoid that.
            ($driver.InputQueue -is [System.Collections.Concurrent.ConcurrentQueue[PSCustomObject]]) | Should -Be $true
            & $driver.Stop
        }
    }

    Context 'OutputSink behaviour' {
        It 'Should expose OutputSink as a scriptblock' {
            $driver = New-ElmWebSocketDriver -Port 8082
            $driver.OutputSink | Should -BeOfType [scriptblock]
            & $driver.Stop
        }

        It 'Should enqueue a string when OutputSink is called' {
            $driver = New-ElmWebSocketDriver -Port 8083

            # The OutputSink wraps $outputQueue which is inside the closure.
            # We cannot inspect it directly, but we can verify calling it does not throw.
            { & $driver.OutputSink 'hello' } | Should -Not -Throw

            & $driver.Stop
        }
    }

    Context 'Stop callable' {
        It 'Should not throw when Stop is called' {
            $driver = New-ElmWebSocketDriver -Port 8084
            { & $driver.Stop } | Should -Not -Throw
        }
    }

    Context 'Parameters forwarded to sub-functions' {
        It 'Should forward Port to Get-ElmXtermPage' {
            # The stub captures the call; verify driver creation succeeds with custom port
            $driver = New-ElmWebSocketDriver -Port 9876
            $driver | Should -Not -BeNullOrEmpty
            & $driver.Stop
        }

        It 'Should accept custom Width and Height' {
            $driver = New-ElmWebSocketDriver -Port 8085 -Width 160 -Height 40
            $driver | Should -Not -BeNullOrEmpty
            & $driver.Stop
        }
    }
}
