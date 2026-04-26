BeforeAll {
    # Stubs needed by Start-ElmWebServer

    function Enable-VirtualTerminal { return $true }

    $script:driverCallArgs = @{}

    function New-ElmWebSocketDriver {
        param($Port, $Width, $Height, $Title)
        $script:driverCallArgs = @{ Port = $Port; Width = $Width; Height = $Height; Title = $Title }

        $q = [System.Collections.Concurrent.ConcurrentQueue[PSCustomObject]]::new()
        return [PSCustomObject]@{
            InputQueue  = $q
            OutputSink  = { param($s) <# no-op #> }
            Stop        = { }
        }
    }

    function Invoke-ElmDriverLoop {
        param($ScriptBlock, $Arguments)
        return [PSCustomObject]@{
            PowerShell = [PSCustomObject]@{ Stop = { } }
            Runspace   = [PSCustomObject]@{ Close = { } }
        }
    }

    $script:eventLoopArgs = @{}

    function Invoke-ElmEventLoop {
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

    . $PSScriptRoot/../Public/Runtime/Start-ElmWebServer.ps1
}

Describe 'Start-ElmWebServer' {

    Context 'Calls event loop (not Start-ElmProgram)' {
        BeforeAll {
            $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{ Value = 42 }; Cmd = $null } }
            $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
            $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = 'x' } }
            Start-ElmWebServer -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -Port 8090
        }

        It 'Should call Invoke-ElmEventLoop (not Start-ElmProgram)' {
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

            Start-ElmWebServer -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn `
                -Port 8091 -Width 160 -Height 40

            $script:eventLoopArgs.TerminalWidth  | Should -Be 160
            $script:eventLoopArgs.TerminalHeight | Should -Be 40
        }
    }

    Context 'Driver creation' {
        It 'Should create driver with correct Port' {
            $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
            $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
            $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = '' } }

            Start-ElmWebServer -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -Port 7777

            $script:driverCallArgs.Port | Should -Be 7777
        }

        It 'Should not throw with all required parameters' {
            $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
            $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
            $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = '' } }

            { Start-ElmWebServer -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -Port 8092 } |
                Should -Not -Throw
        }
    }

    Context 'Tick runspace' {
        It 'Should not start tick loop when TickMs is 0 (default)' {
            $script:driverLoopCalled = $false
            # Override stub to track whether Invoke-ElmDriverLoop was called
            function Invoke-ElmDriverLoop {
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

            Start-ElmWebServer -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -Port 8093 -TickMs 0

            $script:driverLoopCalled | Should -Be $false
        }
    }
}
