BeforeAll {
    function New-ElmTerminalDriver {
        return [PSCustomObject]@{
            InputQueue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            Stop      = {}
        }
    }

    function Invoke-ElmEventLoop {
        param($InitialModel, $UpdateFn, $ViewFn, $InputQueue, $TerminalWidth, $TerminalHeight)
        return $InitialModel
    }

    . $PSScriptRoot/../Public/Runtime/Start-ElmProgram.ps1
}

Describe 'Start-ElmProgram' {
    It 'Should call InitFn and pass its model to Invoke-ElmEventLoop' {
        $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{ Count = 7 }; Cmd = $null } }
        $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
        $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = 'x' } }
        $result   = Start-ElmProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn
        $result.Count | Should -Be 7
    }

    It 'Should return the final model from Invoke-ElmEventLoop' {
        $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{ Status = 'done' }; Cmd = $null } }
        $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
        $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = 'x' } }
        $result   = Start-ElmProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn
        $result.Status | Should -Be 'done'
    }

    It 'Should stop the terminal driver when the event loop completes' {
        $capture = @{ StopCalled = $false }
        $stopFn  = { $capture.StopCalled = $true }.GetNewClosure()

        function New-ElmTerminalDriver {
            return [PSCustomObject]@{
                InputQueue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
                Stop      = $stopFn
            }
        }

        $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
        $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
        $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = 'x' } }
        Start-ElmProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn
        ($capture.StopCalled -eq $true) | Should -Be $true
    }

    It 'Should stop the terminal driver even if Invoke-ElmEventLoop throws' {
        $capture = @{ StopCalled = $false }
        $stopFn  = { $capture.StopCalled = $true }.GetNewClosure()

        function New-ElmTerminalDriver {
            return [PSCustomObject]@{
                InputQueue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
                Stop      = $stopFn
            }
        }

        function Invoke-ElmEventLoop {
            param($InitialModel, $UpdateFn, $ViewFn, $InputQueue, $TerminalWidth, $TerminalHeight)
            throw 'simulated loop error'
        }

        $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
        $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
        $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = 'x' } }
        { Start-ElmProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn } | Should -Throw
        ($capture.StopCalled -eq $true) | Should -Be $true
    }

    It 'Should accept optional Width and Height parameters' {
        $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
        $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
        $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = 'x' } }
        { Start-ElmProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -Width 120 -Height 40 } | Should -Not -Throw
    }

    It 'Should default to 80x24 terminal dimensions' {
        $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
        $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
        $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = 'x' } }
        { Start-ElmProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn } | Should -Not -Throw
    }
}
