BeforeAll {
    . $PSScriptRoot/../Private/Core/Copy-TeaModelValue.ps1
    . $PSScriptRoot/../Private/Core/Copy-TeaModel.ps1
    . $PSScriptRoot/../Private/Runtime/Invoke-TeaUpdate.ps1
}

Describe 'Invoke-TeaUpdate' {
    Context 'Return value' {
        It 'Should return the Model from the Update function' {
            $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = [PSCustomObject]@{ Count = 42 }; Cmd = $null } }
            $model = [PSCustomObject]@{ Count = 0 }
            $result = Invoke-TeaUpdate -UpdateFn $updateFn -Message 'Increment' -Model $model
            $result.Model.Count | Should -Be 42
        }

        It 'Should return the Cmd from the Update function' {
            $cmd = [PSCustomObject]@{ Type = 'Quit' }
            $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $cmd } }
            $model = [PSCustomObject]@{ Count = 0 }
            $result = Invoke-TeaUpdate -UpdateFn $updateFn -Message 'Quit' -Model $model
            $result.Cmd.Type | Should -Be 'Quit'
        }

        It 'Should return null Cmd when Update function returns no command' {
            $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
            $model = [PSCustomObject]@{ Count = 0 }
            $result = Invoke-TeaUpdate -UpdateFn $updateFn -Message 'Noop' -Model $model
            $result.Cmd | Should -BeNullOrEmpty
        }
    }

    Context 'Message forwarding' {
        It 'Should pass the message to the Update function' {
            $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = [PSCustomObject]@{ ReceivedMsg = $msg }; Cmd = $null } }
            $model = [PSCustomObject]@{ Count = 0 }
            $result = Invoke-TeaUpdate -UpdateFn $updateFn -Message 'Increment' -Model $model
            $result.Model.ReceivedMsg | Should -Be 'Increment'
        }

        It 'Should pass a complex message object to the Update function' {
            $updateFn = { param($msg, $model) [PSCustomObject]@{ Model = [PSCustomObject]@{ ReceivedValue = $msg.Value }; Cmd = $null } }
            $model = [PSCustomObject]@{ Count = 0 }
            $complexMsg = [PSCustomObject]@{ Type = 'SetCount'; Value = 99 }
            $result = Invoke-TeaUpdate -UpdateFn $updateFn -Message $complexMsg -Model $model
            $result.Model.ReceivedValue | Should -Be 99
        }
    }

    Context 'Model isolation' {
        It 'Should pass a deep copy of the model to the Update function' {
            # UpdateFn mutates the model it receives; original must be unaffected
            $updateFn = {
                param($msg, $model)
                $model.Count = 999
                [PSCustomObject]@{ Model = $model; Cmd = $null }
            }
            $original = [PSCustomObject]@{ Count = 5 }
            Invoke-TeaUpdate -UpdateFn $updateFn -Message 'noop' -Model $original
            $original.Count | Should -Be 5
        }
    }
}
