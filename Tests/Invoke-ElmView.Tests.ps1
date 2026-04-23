BeforeAll {
    . $PSScriptRoot/../Public/View/New-ElmText.ps1
    . $PSScriptRoot/../Public/View/New-ElmBox.ps1
    . $PSScriptRoot/../Private/Runtime/Invoke-ElmView.ps1
}

Describe 'Invoke-ElmView' {
    Context 'Valid view tree returned' {
        It 'Should return a Text node from the View function' {
            $viewFn = { param($model) New-ElmText -Content 'hello' }
            $model = [PSCustomObject]@{ Count = 0 }
            $result = Invoke-ElmView -ViewFn $viewFn -Model $model
            $result.Type | Should -Be 'Text'
        }

        It 'Should return a Box node from the View function' {
            $viewFn = { param($model) New-ElmBox -Children @(New-ElmText -Content 'item') }
            $model = [PSCustomObject]@{}
            $result = Invoke-ElmView -ViewFn $viewFn -Model $model
            $result.Type | Should -Be 'Box'
        }

        It 'Should pass the model to the View function' {
            $viewFn = { param($model) New-ElmText -Content "Count: $($model.Count)" }
            $model = [PSCustomObject]@{ Count = 7 }
            $result = Invoke-ElmView -ViewFn $viewFn -Model $model
            $result.Content | Should -Be 'Count: 7'
        }
    }

    Context 'Invalid view tree validation' {
        It 'Should throw when View function returns null' {
            $viewFn = { param($model) $null }
            $model = [PSCustomObject]@{}
            { Invoke-ElmView -ViewFn $viewFn -Model $model } | Should -Throw
        }

        It 'Should throw when View function returns an object without Type' {
            $viewFn = { param($model) [PSCustomObject]@{ Foo = 'bar' } }
            $model = [PSCustomObject]@{}
            { Invoke-ElmView -ViewFn $viewFn -Model $model } | Should -Throw
        }

        It 'Should throw when View function returns an unrecognised Type' {
            $viewFn = { param($model) [PSCustomObject]@{ Type = 'Widget' } }
            $model = [PSCustomObject]@{}
            { Invoke-ElmView -ViewFn $viewFn -Model $model } | Should -Throw
        }
    }
}
