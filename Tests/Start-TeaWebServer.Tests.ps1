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

    Context 'Driver shutdown - normal exit (Elm-pia)' {
        BeforeAll {
            $script:stopCalledNormal = $false

            function New-TeaWebSocketDriver {
                param($Port, $Width, $Height, $Title)
                $q = [System.Collections.Concurrent.ConcurrentQueue[PSCustomObject]]::new()
                return [PSCustomObject]@{
                    InputQueue  = $q
                    OutputSink  = { param($s) }
                    Stop        = { $script:stopCalledNormal = $true }
                }
            }

            $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
            $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
            $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = '' } }

            Start-TeaWebServer -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -Port 8095 `
                -InformationAction SilentlyContinue
        }

        It 'Should call driver.Stop after the event loop exits normally' {
            $script:stopCalledNormal | Should -Be $true
        }
    }

    Context 'Driver shutdown - exception path (Elm-pia)' {
        BeforeAll {
            $script:stopCalledOnException = $false

            function New-TeaWebSocketDriver {
                param($Port, $Width, $Height, $Title)
                $q = [System.Collections.Concurrent.ConcurrentQueue[PSCustomObject]]::new()
                return [PSCustomObject]@{
                    InputQueue  = $q
                    OutputSink  = { param($s) }
                    Stop        = { $script:stopCalledOnException = $true }
                }
            }

            function Invoke-TeaEventLoop {
                param($InitialModel, $UpdateFn, $ViewFn, $InputQueue,
                      $SubscriptionFn, $TerminalWidth, $TerminalHeight, $OutputSink)
                throw 'Simulated event loop failure'
            }

            $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
            $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
            $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = '' } }

            try {
                Start-TeaWebServer -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -Port 8096 `
                    -InformationAction SilentlyContinue
            } catch {}
        }

        It 'Should call driver.Stop even when the event loop throws (mimics Ctrl+C)' {
            $script:stopCalledOnException | Should -Be $true
        }
    }

    Context 'Driver shutdown - tick loop cleanup ordering (Elm-pia)' {
        BeforeAll {
            # Use a hashtable (reference type) captured via closure so mutations inside
            # ScriptMethod calls are visible here regardless of scope context.
            $script:tickTrack = @{ PsStopCalled = $false; RsCloseCalled = $false; DriverStopCalled = $false }

            function New-TeaWebSocketDriver {
                param($Port, $Width, $Height, $Title)
                $track = $script:tickTrack
                $q     = [System.Collections.Concurrent.ConcurrentQueue[PSCustomObject]]::new()
                return [PSCustomObject]@{
                    InputQueue  = $q
                    OutputSink  = { param($s) }
                    Stop        = { $track.DriverStopCalled = $true }.GetNewClosure()
                }
            }

            function Invoke-TeaDriverLoop {
                param($ScriptBlock, $Arguments)
                $track  = $script:tickTrack
                $psMock = [PSCustomObject]@{}
                $psMock | Add-Member -MemberType ScriptMethod -Name 'Stop' `
                    -Value { $track.PsStopCalled = $true }.GetNewClosure()
                $rsMock = [PSCustomObject]@{}
                $rsMock | Add-Member -MemberType ScriptMethod -Name 'Close' `
                    -Value { $track.RsCloseCalled = $true }.GetNewClosure()
                return [PSCustomObject]@{
                    PowerShell = $psMock
                    Runspace   = $rsMock
                }
            }

            $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
            $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
            $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = '' } }

            Start-TeaWebServer -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -Port 8097 -TickMs 100 `
                -InformationAction SilentlyContinue
        }

        It 'Should stop the tick PowerShell instance on exit' {
            $script:tickTrack.PsStopCalled | Should -Be $true
        }

        It 'Should close the tick runspace on exit' {
            $script:tickTrack.RsCloseCalled | Should -Be $true
        }

        It 'Should call driver.Stop on exit when tick loop is active' {
            $script:tickTrack.DriverStopCalled | Should -Be $true
        }
    }

    Context 'Previous driver cleanup (Elm-pia)' {
        BeforeAll {
            # Seed the AppDomain slots that Start-TeaWebServer reads on entry.
            # This simulates a previous run that was killed without the finally block firing.
            $script:TeaDriverContainer = [hashtable]::Synchronized(@{ Active = $null })
            [System.AppDomain]::CurrentDomain.SetData('PSTea.DriverContainer', $script:TeaDriverContainer)
        }

        AfterEach {
            $script:TeaDriverContainer.Active = $null
            [System.AppDomain]::CurrentDomain.SetData('PSTea.ActiveListener',    $null)
            [System.AppDomain]::CurrentDomain.SetData('PSTea.ActiveCts',         $null)
            [System.AppDomain]::CurrentDomain.SetData('PSTea.ActiveSharedState', $null)
            [System.AppDomain]::CurrentDomain.SetData('PSTea.ActiveRunspaces',   $null)
        }

        It 'Should stop the previously active driver before creating a new one' {
            # Arrange — simulate a stale listener in the AppDomain slot (what happens when
            # the VS Code Extension kills the runspace without running the finally block).
            $staleListener = [System.Net.HttpListener]::new()
            $staleListener.Prefixes.Add('http://localhost:19877/')
            $staleListener.Start()
            [System.AppDomain]::CurrentDomain.SetData('PSTea.ActiveListener', $staleListener)
            [System.AppDomain]::CurrentDomain.SetData('PSTea.ActiveCts',      [System.Threading.CancellationTokenSource]::new())

            $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
            $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
            $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = '' } }

            # Act — Start-TeaWebServer should stop the stale listener via pure .NET before the port probe
            Start-TeaWebServer -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -Port 8101 `
                -InformationAction SilentlyContinue

            # Assert — stale listener should no longer be listening
            $staleListener.IsListening | Should -Be $false
        }

        It 'Should clear the AppDomain slots after normal exit' {
            $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
            $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
            $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = '' } }

            Start-TeaWebServer -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -Port 8102 `
                -InformationAction SilentlyContinue

            [System.AppDomain]::CurrentDomain.GetData('PSTea.ActiveListener') | Should -BeNullOrEmpty
        }

        It 'Should clear the driver container after normal exit' {
            $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
            $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
            $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = '' } }

            Start-TeaWebServer -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -Port 8102 `
                -InformationAction SilentlyContinue

            $script:TeaDriverContainer.Active | Should -BeNullOrEmpty
        }

        It 'Should clear the AppDomain slots after an exception' {
            function Invoke-TeaEventLoop {
                param($InitialModel, $UpdateFn, $ViewFn, $InputQueue,
                      $SubscriptionFn, $TerminalWidth, $TerminalHeight, $OutputSink)
                throw 'Simulated failure'
            }

            $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
            $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
            $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = '' } }

            try {
                Start-TeaWebServer -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -Port 8103 `
                    -InformationAction SilentlyContinue
            } catch {}

            [System.AppDomain]::CurrentDomain.GetData('PSTea.ActiveListener') | Should -BeNullOrEmpty
        }
    }
}
