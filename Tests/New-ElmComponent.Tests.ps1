BeforeAll {
    . $PSScriptRoot/../Public/View/New-ElmText.ps1
    . $PSScriptRoot/../Public/View/New-ElmComponent.ps1
}

Describe 'New-ElmComponent' {
    Context 'Return shape' {
        It 'Should return Type = Component' {
            $viewFn = { param($m) New-ElmText -Content 'hi' }
            $result = New-ElmComponent -ComponentId 'test' -SubModel ([PSCustomObject]@{}) -ViewFn $viewFn
            $result.Type | Should -Be 'Component'
        }

        It 'Should return the given ComponentId' {
            $viewFn = { param($m) New-ElmText -Content 'hi' }
            $result = New-ElmComponent -ComponentId 'my-widget' -SubModel ([PSCustomObject]@{}) -ViewFn $viewFn
            $result.ComponentId | Should -Be 'my-widget'
        }

        It 'Should return the given SubModel' {
            $model = [PSCustomObject]@{ Value = 42 }
            $viewFn = { param($m) New-ElmText -Content 'hi' }
            $result = New-ElmComponent -ComponentId 'x' -SubModel $model -ViewFn $viewFn
            $result.SubModel.Value | Should -Be 42
        }

        It 'Should return the given ViewFn' {
            $viewFn = { param($m) New-ElmText -Content 'hi' }
            $result = New-ElmComponent -ComponentId 'x' -SubModel ([PSCustomObject]@{}) -ViewFn $viewFn
            $result.ViewFn | Should -Be $viewFn
        }
    }

    Context 'Parameter validation' {
        It 'Should throw when ComponentId is empty string' {
            { New-ElmComponent -ComponentId '' -SubModel ([PSCustomObject]@{}) -ViewFn { } } | Should -Throw
        }

        It 'Should throw when ComponentId is null' {
            { New-ElmComponent -ComponentId $null -SubModel ([PSCustomObject]@{}) -ViewFn { } } | Should -Throw
        }

        It 'Should throw when ViewFn is null' {
            { New-ElmComponent -ComponentId 'x' -SubModel ([PSCustomObject]@{}) -ViewFn $null } | Should -Throw
        }
    }

    Context 'ViewFn is callable with SubModel' {
        It 'Should produce a view node when ViewFn is invoked with SubModel' {
            $model = [PSCustomObject]@{ Label = 'hello' }
            $viewFn = { param($m) New-ElmText -Content $m.Label }
            $component = New-ElmComponent -ComponentId 'label' -SubModel $model -ViewFn $viewFn
            $node = & $component.ViewFn $component.SubModel
            $node.Type    | Should -Be 'Text'
            $node.Content | Should -Be 'hello'
        }
    }
}
