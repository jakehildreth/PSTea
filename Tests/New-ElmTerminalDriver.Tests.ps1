BeforeAll {
    . $PSScriptRoot/../Private/Runtime/Invoke-ElmDriverLoop.ps1
    . $PSScriptRoot/../Private/Drivers/New-ElmTerminalDriver.ps1
}

Describe 'New-ElmTerminalDriver' {
    Context 'Return shape' {
        AfterEach {
            if ($driver) {
                try { & $driver.Stop } catch {}
            }
        }

        It 'Should return an object with an InputQueue property that is not null' {
            $driver = New-ElmTerminalDriver
            ($null -ne $driver.InputQueue) | Should -Be $true
        }

        It 'Should return an InputQueue that is a ConcurrentQueue of PSCustomObject' {
            $driver = New-ElmTerminalDriver
            $driver.InputQueue.GetType().Name | Should -Be 'ConcurrentQueue`1'
        }

        It 'Should return an object with a Stop property' {
            $driver = New-ElmTerminalDriver
            $driver.Stop | Should -Not -BeNullOrEmpty
        }

        It 'Should return a Stop that is a scriptblock' {
            $driver = New-ElmTerminalDriver
            $driver.Stop | Should -BeOfType [scriptblock]
        }

        It 'Should return an object with a Loop property' {
            $driver = New-ElmTerminalDriver
            $driver.Loop | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Stop behaviour' {
        It 'Should stop without throwing when invoked' {
            $driver = New-ElmTerminalDriver
            { & $driver.Stop } | Should -Not -Throw
        }

        It 'Should close the background runspace when Stop is invoked' {
            $driver = New-ElmTerminalDriver
            & $driver.Stop
            $state = $driver.Loop.Runspace.RunspaceStateInfo.State
            $state | Should -BeIn @('Closed', 'Closing', 'Broken')
        }
    }
}
