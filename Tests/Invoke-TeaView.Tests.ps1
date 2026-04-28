BeforeAll {
    . $PSScriptRoot/../Public/View/New-TeaText.ps1
    . $PSScriptRoot/../Public/View/New-TeaBox.ps1
    . $PSScriptRoot/../Private/Runtime/Invoke-TeaView.ps1
}

Describe 'Invoke-TeaView' {
    Context 'Valid view tree returned' {
        It 'Should return a Text node from the View function' {
            $viewFn = { param($model) New-TeaText -Content 'hello' }
            $model = [PSCustomObject]@{ Count = 0 }
            $result = Invoke-TeaView -ViewFn $viewFn -Model $model
            $result.Type | Should -Be 'Text'
        }

        It 'Should return a Box node from the View function' {
            $viewFn = { param($model) New-TeaBox -Children @(New-TeaText -Content 'item') }
            $model = [PSCustomObject]@{}
            $result = Invoke-TeaView -ViewFn $viewFn -Model $model
            $result.Type | Should -Be 'Box'
        }

        It 'Should pass the model to the View function' {
            $viewFn = { param($model) New-TeaText -Content "Count: $($model.Count)" }
            $model = [PSCustomObject]@{ Count = 7 }
            $result = Invoke-TeaView -ViewFn $viewFn -Model $model
            $result.Content | Should -Be 'Count: 7'
        }
    }

    Context 'Invalid view tree validation' {
        It 'Should throw when View function returns null' {
            $viewFn = { param($model) $null }
            $model = [PSCustomObject]@{}
            { Invoke-TeaView -ViewFn $viewFn -Model $model } | Should -Throw
        }

        It 'Should throw when View function returns an object without Type' {
            $viewFn = { param($model) [PSCustomObject]@{ Foo = 'bar' } }
            $model = [PSCustomObject]@{}
            { Invoke-TeaView -ViewFn $viewFn -Model $model } | Should -Throw
        }

        It 'Should throw when View function returns an unrecognised Type' {
            $viewFn = { param($model) [PSCustomObject]@{ Type = 'Widget' } }
            $model = [PSCustomObject]@{}
            { Invoke-TeaView -ViewFn $viewFn -Model $model } | Should -Throw
        }
    }
}
