BeforeAll {
    function Enable-VirtualTerminal { return $true }

    function New-TeaTerminalDriver {
        param([switch]$AltScreen)
        return [PSCustomObject]@{
            InputQueue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            Stop      = {}
        }
    }

    function Invoke-TeaEventLoop {
        param($InitialModel, $UpdateFn, $ViewFn, $InputQueue, $TerminalWidth, $TerminalHeight)
        $script:lastEventLoopWidth  = $TerminalWidth
        $script:lastEventLoopHeight = $TerminalHeight
        return $InitialModel
    }

    . $PSScriptRoot/../Public/Runtime/Start-TeaProgram.ps1
}

Describe 'Start-TeaProgram' {
    It 'Should call InitFn and pass its model to Invoke-TeaEventLoop' {
        $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{ Count = 7 }; Cmd = $null } }
        $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
        $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = 'x' } }
        $result   = Start-TeaProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn
        $result.Count | Should -Be 7
    }

    It 'Should return the final model from Invoke-TeaEventLoop' {
        $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{ Status = 'done' }; Cmd = $null } }
        $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
        $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = 'x' } }
        $result   = Start-TeaProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn
        $result.Status | Should -Be 'done'
    }

    It 'Should stop the terminal driver when the event loop completes' {
        $capture = @{ StopCalled = $false }
        $stopFn  = { $capture.StopCalled = $true }.GetNewClosure()

        function New-TeaTerminalDriver {
            param([switch]$AltScreen)
            return [PSCustomObject]@{
                InputQueue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
                Stop      = $stopFn
            }
        }

        $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
        $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
        $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = 'x' } }
        Start-TeaProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn
        ($capture.StopCalled -eq $true) | Should -Be $true
    }

    It 'Should stop the terminal driver even if Invoke-TeaEventLoop throws' {
        $capture = @{ StopCalled = $false }
        $stopFn  = { $capture.StopCalled = $true }.GetNewClosure()

        function New-TeaTerminalDriver {
            param([switch]$AltScreen)
            return [PSCustomObject]@{
                InputQueue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
                Stop      = $stopFn
            }
        }

        function Invoke-TeaEventLoop {
            param($InitialModel, $UpdateFn, $ViewFn, $InputQueue, $TerminalWidth, $TerminalHeight)
            throw 'simulated loop error'
        }

        $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
        $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
        $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = 'x' } }
        { Start-TeaProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn } | Should -Throw
        ($capture.StopCalled -eq $true) | Should -Be $true
    }

    It 'Should accept optional Width and Height parameters within terminal bounds' {
        $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
        $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
        $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = 'x' } }
        $termW = if ([Console]::WindowWidth  -gt 0) { [Console]::WindowWidth  } else { 80 }
        $termH = if ([Console]::WindowHeight -gt 0) { [Console]::WindowHeight } else { 24 }
        { Start-TeaProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -Width $termW -Height $termH } | Should -Not -Throw
    }

    It 'Should default Width and Height to console dimensions' {
        $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
        $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
        $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = 'x' } }
        Start-TeaProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn
        $expectedWidth  = if ([Console]::WindowWidth  -gt 0) { [Console]::WindowWidth  } else { 80 }
        $expectedHeight = if ([Console]::WindowHeight -gt 0) { [Console]::WindowHeight } else { 24 }
        $script:lastEventLoopWidth  | Should -Be $expectedWidth
        $script:lastEventLoopHeight | Should -Be $expectedHeight
    }

    It 'Should throw a terminating error when Width exceeds terminal width' {
        $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
        $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
        $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = 'x' } }
        { Start-TeaProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -Width 999999 } | Should -Throw
    }

    It 'Should throw a terminating error when Height exceeds terminal height' {
        $initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null } }
        $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
        $viewFn   = { param($model) [PSCustomObject]@{ Type = 'Text'; Content = 'x' } }
        { Start-TeaProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -Height 999999 } | Should -Throw
    }
}

