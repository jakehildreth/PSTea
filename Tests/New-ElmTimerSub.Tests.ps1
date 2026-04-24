BeforeAll {
    . $PSScriptRoot/../Public/Subscriptions/New-ElmTimerSub.ps1
}

Describe 'New-ElmTimerSub' -Tag 'Unit', 'P6' {

    Context 'Return value structure' {
        BeforeAll {
            $sub = New-ElmTimerSub -IntervalMs 1000 -Handler { 'Tick' }
        }

        It 'Should return an object with Type=Timer' {
            $sub.Type | Should -Be 'Timer'
        }

        It 'Should return an object with IntervalMs property' {
            $sub.IntervalMs | Should -Be 1000
        }

        It 'Should return an object with a Handler scriptblock' {
            $sub.Handler | Should -BeOfType [scriptblock]
        }
    }

    Context 'Various intervals' {
        It 'Should accept 1ms (minimum)' {
            $sub = New-ElmTimerSub -IntervalMs 1 -Handler { 'x' }
            $sub.IntervalMs | Should -Be 1
        }

        It 'Should accept 500ms' {
            $sub = New-ElmTimerSub -IntervalMs 500 -Handler { 'x' }
            $sub.IntervalMs | Should -Be 500
        }

        It 'Should accept 60000ms (1 minute)' {
            $sub = New-ElmTimerSub -IntervalMs 60000 -Handler { 'x' }
            $sub.IntervalMs | Should -Be 60000
        }
    }

    Context 'Handler invocation' {
        It 'Should invoke handler and return a string message' {
            $sub = New-ElmTimerSub -IntervalMs 1000 -Handler { 'Tick' }
            $msg = & $sub.Handler
            $msg | Should -Be 'Tick'
        }

        It 'Should invoke handler that returns a PSCustomObject' {
            $sub = New-ElmTimerSub -IntervalMs 200 -Handler {
                [PSCustomObject]@{ Type = 'Frame'; At = 42 }
            }
            $msg = & $sub.Handler
            $msg.Type | Should -Be 'Frame'
            $msg.At   | Should -Be 42
        }

        It 'Should allow handler that returns null' {
            $sub = New-ElmTimerSub -IntervalMs 100 -Handler { $null }
            $msg = & $sub.Handler
            $msg | Should -BeNullOrEmpty
        }
    }

    Context 'Error handling' {
        It 'Should throw when IntervalMs is 0' {
            { New-ElmTimerSub -IntervalMs 0 -Handler { 'x' } } | Should -Throw
        }

        It 'Should throw when IntervalMs is negative' {
            { New-ElmTimerSub -IntervalMs -1 -Handler { 'x' } } | Should -Throw
        }
    }
}
