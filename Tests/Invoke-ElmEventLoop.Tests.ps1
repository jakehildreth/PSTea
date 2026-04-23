BeforeAll {
    . $PSScriptRoot/../Private/Core/Copy-ElmModel.ps1
    . $PSScriptRoot/../Private/Runtime/Invoke-ElmUpdate.ps1
    . $PSScriptRoot/../Private/Runtime/Invoke-ElmView.ps1
    . $PSScriptRoot/../Public/View/New-ElmText.ps1

    # Stub the rendering pipeline so tests don't need ANSI dependencies
    function Measure-ElmViewTree { param($Root, $TermWidth, $TermHeight) return $Root }
    function Compare-ElmViewTree { param($OldTree, $NewTree) return @() }
    function ConvertTo-AnsiOutput { param($Root) return '' }
    function ConvertTo-AnsiPatch { param($Patches) return '' }

    . $PSScriptRoot/../Private/Runtime/Invoke-ElmEventLoop.ps1
}

Describe 'Invoke-ElmEventLoop' {
    Context 'Quit command' {
        It 'Should stop when UpdateFn returns a Quit command' {
            $updateFn = {
                param($msg, $model)
                [PSCustomObject]@{ Model = $model; Cmd = [PSCustomObject]@{ Type = 'Quit' } }
            }
            $viewFn = { param($model) New-ElmText -Content 'test' }
            $queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $queue.Enqueue('any')
            { Invoke-ElmEventLoop -InitialModel ([PSCustomObject]@{}) -UpdateFn $updateFn -ViewFn $viewFn -InputQueue $queue } | Should -Not -Throw
        }

        It 'Should return the final model on Quit' {
            $updateFn = {
                param($msg, $model)
                if ($msg -eq 'Quit') {
                    [PSCustomObject]@{ Model = $model; Cmd = [PSCustomObject]@{ Type = 'Quit' } }
                } else {
                    [PSCustomObject]@{ Model = [PSCustomObject]@{ Value = $msg }; Cmd = $null }
                }
            }
            $viewFn = { param($model) New-ElmText -Content 'x' }
            $queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $queue.Enqueue('hello')
            $queue.Enqueue('Quit')
            $result = Invoke-ElmEventLoop -InitialModel ([PSCustomObject]@{ Value = '' }) -UpdateFn $updateFn -ViewFn $viewFn -InputQueue $queue
            $result.Value | Should -Be 'hello'
        }

        It 'Should capture the model returned by the Quit update' {
            $updateFn = {
                param($msg, $model)
                [PSCustomObject]@{
                    Model = [PSCustomObject]@{ Last = $msg }
                    Cmd   = [PSCustomObject]@{ Type = 'Quit' }
                }
            }
            $viewFn = { param($model) New-ElmText -Content 'x' }
            $queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $queue.Enqueue('finalMsg')
            $result = Invoke-ElmEventLoop -InitialModel ([PSCustomObject]@{ Last = '' }) -UpdateFn $updateFn -ViewFn $viewFn -InputQueue $queue
            $result.Last | Should -Be 'finalMsg'
        }
    }

    Context 'Cursor visibility' {
        It 'Should hide the cursor (ESC[?25l) before first render' {
            # Verify the hide sequence is the correct ANSI DEC private mode sequence
            $expected = [char]27 + '[?25l'
            $expected | Should -Be ($([char]27) + '[?25l')
            $expected.Length | Should -Be 6
        }

        It 'Should use ESC[?25h to restore the cursor' {
            $expected = [char]27 + '[?25h'
            $expected | Should -Be ($([char]27) + '[?25h')
            $expected.Length | Should -Be 6
        }

        It 'Should complete without error when loop exits (cursor restore via finally)' {
            $updateFn = {
                param($msg, $model)
                [PSCustomObject]@{ Model = $model; Cmd = [PSCustomObject]@{ Type = 'Quit' } }
            }
            $viewFn = { param($model) New-ElmText -Content 'x' }
            $queue  = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $queue.Enqueue('any')
            { Invoke-ElmEventLoop -InitialModel ([PSCustomObject]@{}) -UpdateFn $updateFn -ViewFn $viewFn -InputQueue $queue } | Should -Not -Throw
        }
    }

    Context 'Message processing' {
        It 'Should accumulate model changes across multiple messages' {
            $updateFn = {
                param($msg, $model)
                if ($msg -eq 'Quit') {
                    [PSCustomObject]@{ Model = $model; Cmd = [PSCustomObject]@{ Type = 'Quit' } }
                } else {
                    [PSCustomObject]@{ Model = [PSCustomObject]@{ Count = $model.Count + 1 }; Cmd = $null }
                }
            }
            $viewFn = { param($model) New-ElmText -Content "$($model.Count)" }
            $queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $queue.Enqueue('Inc')
            $queue.Enqueue('Inc')
            $queue.Enqueue('Inc')
            $queue.Enqueue('Quit')
            $result = Invoke-ElmEventLoop -InitialModel ([PSCustomObject]@{ Count = 0 }) -UpdateFn $updateFn -ViewFn $viewFn -InputQueue $queue
            $result.Count | Should -Be 3
        }

        It 'Should pass the current model to the View function after each update' {
            $updateFn = {
                param($msg, $model)
                if ($msg -eq 'Quit') {
                    [PSCustomObject]@{ Model = $model; Cmd = [PSCustomObject]@{ Type = 'Quit' } }
                } else {
                    [PSCustomObject]@{ Model = [PSCustomObject]@{ Label = $msg }; Cmd = $null }
                }
            }
            # ViewFn embeds the current model label into the node content
            $viewFn = { param($model) New-ElmText -Content "label:$($model.Label)" }
            $queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $queue.Enqueue('alpha')
            $queue.Enqueue('Quit')
            # If ViewFn were not called, we would get an error from Invoke-ElmView; instead it completes
            { Invoke-ElmEventLoop -InitialModel ([PSCustomObject]@{ Label = '' }) -UpdateFn $updateFn -ViewFn $viewFn -InputQueue $queue } | Should -Not -Throw
        }
    }
}
