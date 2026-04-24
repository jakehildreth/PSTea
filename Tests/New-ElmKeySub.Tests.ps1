BeforeAll {
    . $PSScriptRoot/../Private/Subscriptions/ConvertFrom-ElmKeyString.ps1
    . $PSScriptRoot/../Public/Subscriptions/New-ElmKeySub.ps1
}

Describe 'New-ElmKeySub' -Tag 'Unit', 'P6' {

    Context 'Return value structure' {
        BeforeAll {
            $sub = New-ElmKeySub -Key 'Q' -Handler { 'Quit' }
        }

        It 'Should return an object with Type=Key' {
            $sub.Type | Should -Be 'Key'
        }

        It 'Should return an object with ConsoleKey property' {
            $sub.ConsoleKey | Should -Be ([System.ConsoleKey]::Q)
        }

        It 'Should return an object with Modifiers property (no modifier = 0)' {
            [int]$sub.Modifiers | Should -Be 0
        }

        It 'Should return an object with a Handler scriptblock' {
            $sub.Handler | Should -BeOfType [scriptblock]
        }
    }

    Context 'Modifier keys' {
        It 'Should set Modifiers=Control for Ctrl+Q' {
            $sub = New-ElmKeySub -Key 'Ctrl+Q' -Handler { 'Quit' }
            $sub.Modifiers | Should -Be ([System.ConsoleModifiers]::Control)
        }

        It 'Should set Modifiers=Alt for Alt+F4' {
            $sub = New-ElmKeySub -Key 'Alt+F4' -Handler { 'Exit' }
            $sub.Modifiers | Should -Be ([System.ConsoleModifiers]::Alt)
        }
    }

    Context 'Special key strings' {
        It 'Should accept UpArrow' {
            $sub = New-ElmKeySub -Key 'UpArrow' -Handler { 'Up' }
            $sub.ConsoleKey | Should -Be ([System.ConsoleKey]::UpArrow)
        }

        It 'Should accept Space alias' {
            $sub = New-ElmKeySub -Key 'Space' -Handler { 'Space' }
            $sub.ConsoleKey | Should -Be ([System.ConsoleKey]::Spacebar)
        }

        It 'Should accept Esc alias' {
            $sub = New-ElmKeySub -Key 'Esc' -Handler { 'Back' }
            $sub.ConsoleKey | Should -Be ([System.ConsoleKey]::Escape)
        }
    }

    Context 'Handler invocation' {
        It 'Should invoke handler and return a string message' {
            $sub = New-ElmKeySub -Key 'Q' -Handler { 'Quit' }
            $msg = & $sub.Handler
            $msg | Should -Be 'Quit'
        }

        It 'Should invoke handler that receives a key event argument' {
            $sub = New-ElmKeySub -Key 'Q' -Handler {
                param($e)
                [PSCustomObject]@{ Type = 'KeyMsg'; Key = $e.Key }
            }
            $fakeEvent = [PSCustomObject]@{ Type = 'KeyDown'; Key = [System.ConsoleKey]::Q; Modifiers = [System.ConsoleModifiers]0 }
            $msg = & $sub.Handler $fakeEvent
            $msg.Type | Should -Be 'KeyMsg'
            $msg.Key  | Should -Be ([System.ConsoleKey]::Q)
        }

        It 'Should allow handler that returns null' {
            $sub = New-ElmKeySub -Key 'Q' -Handler { $null }
            $msg = & $sub.Handler
            $msg | Should -BeNullOrEmpty
        }
    }

    Context 'Error handling' {
        It 'Should throw when Key is invalid' {
            { New-ElmKeySub -Key 'Blarg' -Handler { 'x' } } | Should -Throw
        }

        It 'Should throw when Key has unknown modifier' {
            { New-ElmKeySub -Key 'Meta+Q' -Handler { 'x' } } | Should -Throw
        }
    }
}
