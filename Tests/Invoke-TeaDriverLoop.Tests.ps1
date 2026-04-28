BeforeAll {
    . $PSScriptRoot/../Private/Runtime/Invoke-TeaDriverLoop.ps1
}

Describe 'Invoke-TeaDriverLoop' {
    Context 'Return type' {
        AfterEach {
            if ($result) {
                try { $result.PowerShell.Dispose() } catch {}
                try { $result.Runspace.Close(); $result.Runspace.Dispose() } catch {}
            }
        }

        It 'Should return a PSCustomObject' {
            $result = Invoke-TeaDriverLoop -ScriptBlock { }
            $result.GetType().FullName | Should -Be 'System.Management.Automation.PSCustomObject'
        }
    }

    Context 'Return shape' {
        AfterEach {
            if ($result) {
                try { $result.PowerShell.Dispose() } catch {}
                try { $result.Runspace.Close(); $result.Runspace.Dispose() } catch {}
            }
        }

        It 'Should return an object with Runspace property' {
            $result = Invoke-TeaDriverLoop -ScriptBlock { }
            $result.Runspace | Should -Not -BeNullOrEmpty
        }

        It 'Should return an object with PowerShell property' {
            $result = Invoke-TeaDriverLoop -ScriptBlock { }
            $result.PowerShell | Should -Not -BeNullOrEmpty
        }

        It 'Should return an object with AsyncResult property' {
            $result = Invoke-TeaDriverLoop -ScriptBlock { }
            $result.AsyncResult | Should -Not -BeNullOrEmpty
        }

        It 'Should return a Runspace that is not broken' {
            $result = Invoke-TeaDriverLoop -ScriptBlock { Start-Sleep -Milliseconds 500 }
            $result.Runspace.RunspaceStateInfo.State | Should -Not -Be 'Broken'
        }
    }

    Context 'Script execution' {
        It 'Should execute the scriptblock in the background runspace' {
            $bag = @{}
            $result = Invoke-TeaDriverLoop -ScriptBlock { param($b) $b['result'] = 'executed' } -Arguments @($bag)
            $result.PowerShell.EndInvoke($result.AsyncResult)
            $bag['result'] | Should -Be 'executed'
            $result.PowerShell.Dispose()
            $result.Runspace.Close()
            $result.Runspace.Dispose()
        }

        It 'Should pass multiple Arguments to the scriptblock' {
            $bag = @{}
            $result = Invoke-TeaDriverLoop -ScriptBlock { param($b, $val) $b['value'] = $val } -Arguments @($bag, 42)
            $result.PowerShell.EndInvoke($result.AsyncResult)
            $bag['value'] | Should -Be 42
            $result.PowerShell.Dispose()
            $result.Runspace.Close()
            $result.Runspace.Dispose()
        }
    }
}
