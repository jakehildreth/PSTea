BeforeAll {
    # Stubs needed by Start-TeaWebServer

    function Enable-VirtualTerminal { return $true }

    $script:driverCallArgs = @{}

    function New-TeaWebSocketDriver {
        param($Port, $Width, $Height, $Title)
        $script:driverCallArgs = @{ Port = $Port; Width = $Width; Height = $Height; Title = $Title }

        $q = [System.Collections.Concurrent.ConcurrentQueue[PSCustomObject]]::new()
        return [PSCustomObject]@{
            InputQueue  = $q
            OutputSink  = { param($s) <# no-op #> }
            Stop        = { }
        }
    }

    function Invoke-TeaDriverLoop {
        param($ScriptBlock, $Arguments)
        return [PSCustomObject]@{
            PowerShell = [PSCustomObject]@{ Stop = { } }
            Runspace   = [PSCustomObject]@{ Close = { } }
        }
    }

    $script:eventLoopArgs = @{}

    function Invoke-TeaEventLoop {
        param(
            $InitialModel, $UpdateFn, $ViewFn, $InputQueue,
            $SubscriptionFn, $TerminalWidth, $TerminalHeight, $OutputSink
        )
        $script:eventLoopArgs = @{
            InitialModel   = $InitialModel
            TerminalWidth  = $TerminalWidth
            TerminalHeight = $TerminalHeight
            OutputSink     = $OutputSink
            InputQueue     = $InputQueue
        }
        return $InitialModel
    }

    . $PSScriptRoot/../Public/Runtime/Start-TeaWebServer.ps1
}

Describe 'Start-TeaWebServer' {

    Context 'Calls event loop (not Start-TeaProgram)' {
        BeforeAll {
            $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{ Value = 42 }; Cmd = $null } }
            $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
            $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = 'x' } }
            Start-TeaWebServer -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -Port 8090
        }

        It 'Should call Invoke-TeaEventLoop (not Start-TeaProgram)' {
            $script:eventLoopArgs | Should -Not -BeNullOrEmpty
        }

        It 'Should pass the initial model to the event loop' {
            $script:eventLoopArgs.InitialModel.Value | Should -Be 42
        }

        It 'Should pass TerminalWidth from -Width' {
            $script:eventLoopArgs.TerminalWidth | Should -Be 220  # default
        }

        It 'Should pass TerminalHeight from -Height' {
            $script:eventLoopArgs.TerminalHeight | Should -Be 50  # default
        }

        It 'Should pass OutputSink from driver' {
            $script:eventLoopArgs.OutputSink | Should -BeOfType [scriptblock]
        }

        It 'Should pass InputQueue from driver' {
            # An empty ConcurrentQueue piped through the pipeline yields $null; check with -ne
            ($null -ne $script:eventLoopArgs.InputQueue) | Should -Be $true
        }
    }

    Context 'Width/Height forwarding' {
        It 'Should forward custom Width and Height to event loop' {
            $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
            $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
            $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = '' } }

            $serverParams = @{
                InitFn   = $initFn
                UpdateFn = $updateFn
                ViewFn   = $viewFn
                Port     = 8091
                Width    = 160
                Height   = 40
            }
            Start-TeaWebServer @serverParams

            $script:eventLoopArgs.TerminalWidth  | Should -Be 160
            $script:eventLoopArgs.TerminalHeight | Should -Be 40
        }
    }

    Context 'Driver creation' {
        It 'Should create driver with correct Port' {
            $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
            $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
            $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = '' } }

            Start-TeaWebServer -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -Port 7777

            $script:driverCallArgs.Port | Should -Be 7777
        }

        It 'Should not throw with all required parameters' {
            $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
            $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
            $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = '' } }

            { Start-TeaWebServer -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -Port 8092 } |
                Should -Not -Throw
        }
    }

    Context 'Port in use' {
        BeforeAll {
            $script:occupiedListener = [System.Net.HttpListener]::new()
            $script:occupiedListener.Prefixes.Add('http://localhost:19876/')
            $script:occupiedListener.Start()
        }

        AfterAll {
            $script:occupiedListener.Stop()
            $script:occupiedListener.Close()
        }

        It 'Should throw a terminating error with ResourceUnavailable when port is in use' {
            $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
            $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
            $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = '' } }

            { Start-TeaWebServer -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -Port 19876 } |
                Should -Throw '*19876*'
        }

        It 'Should include ResourceUnavailable category in the error record' {
            $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
            $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
            $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = '' } }

            try {
                $serverParams = @{
                    InitFn      = $initFn
                    UpdateFn    = $updateFn
                    ViewFn      = $viewFn
                    Port        = 19876
                    ErrorAction = 'Stop'
                }
                Start-TeaWebServer @serverParams
            } catch {
                $_.CategoryInfo.Category | Should -Be 'ResourceUnavailable'
            }
        }
    }

    Context 'Startup message' {
        It 'Should emit an information record containing the port number' {
            $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
            $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
            $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = '' } }

            Start-TeaWebServer -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -Port 8094 `
                -InformationVariable infoVar -InformationAction SilentlyContinue

            $infoVar[0].MessageData | Should -Match '8094'
        }
    }

    Context 'Tick runspace' {
        It 'Should not start tick loop when TickMs is 0 (default)' {
            $script:driverLoopCalled = $false
            # Override stub to track whether Invoke-TeaDriverLoop was called
            function Invoke-TeaDriverLoop {
                param($ScriptBlock, $Arguments)
                $script:driverLoopCalled = $true
                return [PSCustomObject]@{
                    PowerShell = [PSCustomObject]@{ Stop = { } }
                    Runspace   = [PSCustomObject]@{ Close = { } }
                }
            }

            $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
            $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
            $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = '' } }

            Start-TeaWebServer -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -Port 8093 -TickMs 0

            $script:driverLoopCalled | Should -Be $false
        }
    }
}
