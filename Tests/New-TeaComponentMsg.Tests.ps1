BeforeAll {
    . $PSScriptRoot/../Public/View/New-TeaComponentMsg.ps1
}

Describe 'New-TeaComponentMsg' {
    Context 'Return shape' {
        It 'Should return Type = ComponentMsg' {
            $result = New-TeaComponentMsg -ComponentId 'search' -Msg 'CharInput'
            $result.Type | Should -Be 'ComponentMsg'
        }

        It 'Should return the given ComponentId' {
            $result = New-TeaComponentMsg -ComponentId 'my-list' -Msg 'SelectNext'
            $result.ComponentId | Should -Be 'my-list'
        }

        It 'Should return the given Msg' {
            $innerMsg = [PSCustomObject]@{ Type = 'CharInput'; Char = 'a' }
            $result = New-TeaComponentMsg -ComponentId 'search' -Msg $innerMsg
            $result.Msg.Type | Should -Be 'CharInput'
            $result.Msg.Char | Should -Be 'a'
        }

        It 'Should accept a string as Msg' {
            $result = New-TeaComponentMsg -ComponentId 'x' -Msg 'Quit'
            $result.Msg | Should -Be 'Quit'
        }

        It 'Should accept a PSCustomObject as Msg' {
            $msg = [PSCustomObject]@{ Type = 'KeyDown'; Key = 'Enter' }
            $result = New-TeaComponentMsg -ComponentId 'x' -Msg $msg
            $result.Msg.Key | Should -Be 'Enter'
        }
    }

    Context 'Parameter validation' {
        It 'Should throw when ComponentId is empty string' {
            { New-TeaComponentMsg -ComponentId '' -Msg 'whatever' } | Should -Throw
        }

        It 'Should throw when ComponentId is null' {
            { New-TeaComponentMsg -ComponentId $null -Msg 'whatever' } | Should -Throw
        }
    }
}
