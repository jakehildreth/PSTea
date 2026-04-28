BeforeAll {
    . $PSScriptRoot/../Public/View/New-TeaText.ps1
    . $PSScriptRoot/../Public/View/New-TeaComponent.ps1
}

Describe 'New-TeaComponent' {
    Context 'Return shape' {
        It 'Should return Type = Component' {
            $viewFn = { param($m) New-TeaText -Content 'hi' }
            $result = New-TeaComponent -ComponentId 'test' -SubModel ([PSCustomObject]@{}) -ViewFn $viewFn
            $result.Type | Should -Be 'Component'
        }

        It 'Should return the given ComponentId' {
            $viewFn = { param($m) New-TeaText -Content 'hi' }
            $result = New-TeaComponent -ComponentId 'my-widget' -SubModel ([PSCustomObject]@{}) -ViewFn $viewFn
            $result.ComponentId | Should -Be 'my-widget'
        }

        It 'Should return the given SubModel' {
            $model = [PSCustomObject]@{ Value = 42 }
            $viewFn = { param($m) New-TeaText -Content 'hi' }
            $result = New-TeaComponent -ComponentId 'x' -SubModel $model -ViewFn $viewFn
            $result.SubModel.Value | Should -Be 42
        }

        It 'Should return the given ViewFn' {
            $viewFn = { param($m) New-TeaText -Content 'hi' }
            $result = New-TeaComponent -ComponentId 'x' -SubModel ([PSCustomObject]@{}) -ViewFn $viewFn
            $result.ViewFn | Should -Be $viewFn
        }
    }

    Context 'Parameter validation' {
        It 'Should throw when ComponentId is empty string' {
            { New-TeaComponent -ComponentId '' -SubModel ([PSCustomObject]@{}) -ViewFn { } } | Should -Throw
        }

        It 'Should throw when ComponentId is null' {
            { New-TeaComponent -ComponentId $null -SubModel ([PSCustomObject]@{}) -ViewFn { } } | Should -Throw
        }

        It 'Should throw when ViewFn is null' {
            { New-TeaComponent -ComponentId 'x' -SubModel ([PSCustomObject]@{}) -ViewFn $null } | Should -Throw
        }
    }

    Context 'ViewFn is callable with SubModel' {
        It 'Should produce a view node when ViewFn is invoked with SubModel' {
            $model = [PSCustomObject]@{ Label = 'hello' }
            $viewFn = { param($m) New-TeaText -Content $m.Label }
            $component = New-TeaComponent -ComponentId 'label' -SubModel $model -ViewFn $viewFn
            $node = & $component.ViewFn $component.SubModel
            $node.Type    | Should -Be 'Text'
            $node.Content | Should -Be 'hello'
        }
    }
}
