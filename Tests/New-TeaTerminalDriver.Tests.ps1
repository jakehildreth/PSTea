BeforeAll {
    . $PSScriptRoot/../Private/Runtime/Invoke-TeaDriverLoop.ps1
    . $PSScriptRoot/../Private/Drivers/New-TeaTerminalDriver.ps1
}

Describe 'New-TeaTerminalDriver' {
    Context 'Return shape' {
        AfterEach {
            if ($driver) {
                try { & $driver.Stop } catch {}
            }
        }

        It 'Should return an object with an InputQueue property that is not null' {
            $driver = New-TeaTerminalDriver
            ($null -ne $driver.InputQueue) | Should -Be $true
        }

        It 'Should return an InputQueue that is a ConcurrentQueue of PSCustomObject' {
            $driver = New-TeaTerminalDriver
            $driver.InputQueue.GetType().Name | Should -Be 'ConcurrentQueue`1'
        }

        It 'Should return an object with a Stop property' {
            $driver = New-TeaTerminalDriver
            $driver.Stop | Should -Not -BeNullOrEmpty
        }

        It 'Should return a Stop that is a scriptblock' {
            $driver = New-TeaTerminalDriver
            $driver.Stop | Should -BeOfType [scriptblock]
        }

        It 'Should return an object with a Loop property' {
            $driver = New-TeaTerminalDriver
            $driver.Loop | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Stop behaviour' {
        It 'Should stop without throwing when invoked' {
            $driver = New-TeaTerminalDriver
            { & $driver.Stop } | Should -Not -Throw
        }

        It 'Should close the background runspace when Stop is invoked' {
            $driver = New-TeaTerminalDriver
            & $driver.Stop
            $state = $driver.Loop.Runspace.RunspaceStateInfo.State
            $state | Should -BeIn @('Closed', 'Closing', 'Broken')
        }
    }
}
