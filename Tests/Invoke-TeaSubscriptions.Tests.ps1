BeforeAll {
    . $PSScriptRoot/../Private/Subscriptions/ConvertFrom-TeaKeyString.ps1
    . $PSScriptRoot/../Public/Subscriptions/New-TeaKeySub.ps1
    . $PSScriptRoot/../Public/Subscriptions/New-TeaTimerSub.ps1
    . $PSScriptRoot/../Private/Subscriptions/Invoke-TeaSubscriptions.ps1
}

Describe 'Invoke-TeaSubscriptions' -Tag 'Unit', 'P6' {

    Context 'Empty subscriptions - pass-through mode' {
        It 'Should return an empty array when queue is empty and no subs' {
            $queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $state  = @{}
            $result = @(Invoke-TeaSubscriptions -Subscriptions @() -InputQueue $queue -TimerState $state)
            $result.Count | Should -Be 0
        }

        It 'Should forward raw KeyDown events when no key subs are defined' {
            $queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $queue.Enqueue([PSCustomObject]@{ Type = 'KeyDown'; Key = [System.ConsoleKey]::Q; Char = [char]0; Modifiers = [System.ConsoleModifiers]0 })
            $state  = @{}
            $result = @(Invoke-TeaSubscriptions -Subscriptions @() -InputQueue $queue -TimerState $state)
            $result.Count   | Should -Be 1
            $result[0].Type | Should -Be 'KeyDown'
            $result[0].Key  | Should -Be ([System.ConsoleKey]::Q)
        }

        It 'Should forward multiple raw KeyDown events in order' {
            $queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $queue.Enqueue([PSCustomObject]@{ Type = 'KeyDown'; Key = [System.ConsoleKey]::Q; Char = [char]0; Modifiers = [System.ConsoleModifiers]0 })
            $queue.Enqueue([PSCustomObject]@{ Type = 'KeyDown'; Key = [System.ConsoleKey]::W; Char = [char]0; Modifiers = [System.ConsoleModifiers]0 })
            $state  = @{}
            $result = @(Invoke-TeaSubscriptions -Subscriptions @() -InputQueue $queue -TimerState $state)
            $result.Count  | Should -Be 2
            $result[0].Key | Should -Be ([System.ConsoleKey]::Q)
            $result[1].Key | Should -Be ([System.ConsoleKey]::W)
        }

        It 'Should accept null Subscriptions in pass-through mode' {
            $queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $queue.Enqueue([PSCustomObject]@{ Type = 'KeyDown'; Key = [System.ConsoleKey]::A; Char = [char]0; Modifiers = [System.ConsoleModifiers]0 })
            $state  = @{}
            $result = @(Invoke-TeaSubscriptions -Subscriptions $null -InputQueue $queue -TimerState $state)
            $result.Count | Should -Be 1
        }
    }

    Context 'Key subscriptions - matching' {
        It 'Should invoke handler and return message for matching key' {
            $sub   = New-TeaKeySub -Key 'Q' -Handler { 'Quit' }
            $queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $queue.Enqueue([PSCustomObject]@{ Type = 'KeyDown'; Key = [System.ConsoleKey]::Q; Char = [char]0; Modifiers = [System.ConsoleModifiers]0 })
            $state  = @{}
            $result = @(Invoke-TeaSubscriptions -Subscriptions @($sub) -InputQueue $queue -TimerState $state)
            $result.Count | Should -Be 1
            $result[0]    | Should -Be 'Quit'
        }

        It 'Should drop non-matching key events when key subs are defined' {
            $sub   = New-TeaKeySub -Key 'Q' -Handler { 'Quit' }
            $queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $queue.Enqueue([PSCustomObject]@{ Type = 'KeyDown'; Key = [System.ConsoleKey]::W; Char = [char]0; Modifiers = [System.ConsoleModifiers]0 })
            $state  = @{}
            $result = @(Invoke-TeaSubscriptions -Subscriptions @($sub) -InputQueue $queue -TimerState $state)
            $result.Count | Should -Be 0
        }

        It 'Should match multiple different key subs in one pass' {
            $subQ = New-TeaKeySub -Key 'Q' -Handler { 'Quit' }
            $subW = New-TeaKeySub -Key 'W' -Handler { 'Up'   }
            $queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $queue.Enqueue([PSCustomObject]@{ Type = 'KeyDown'; Key = [System.ConsoleKey]::Q; Char = [char]0; Modifiers = [System.ConsoleModifiers]0 })
            $queue.Enqueue([PSCustomObject]@{ Type = 'KeyDown'; Key = [System.ConsoleKey]::W; Char = [char]0; Modifiers = [System.ConsoleModifiers]0 })
            $state  = @{}
            $result = @(Invoke-TeaSubscriptions -Subscriptions @($subQ, $subW) -InputQueue $queue -TimerState $state)
            $result.Count | Should -Be 2
            $result[0]    | Should -Be 'Quit'
            $result[1]    | Should -Be 'Up'
        }

        It 'Should suppress null handler results' {
            $sub   = New-TeaKeySub -Key 'Q' -Handler { $null }
            $queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $queue.Enqueue([PSCustomObject]@{ Type = 'KeyDown'; Key = [System.ConsoleKey]::Q; Char = [char]0; Modifiers = [System.ConsoleModifiers]0 })
            $state  = @{}
            $result = @(Invoke-TeaSubscriptions -Subscriptions @($sub) -InputQueue $queue -TimerState $state)
            $result.Count | Should -Be 0
        }
    }

    Context 'Key subscriptions - case-insensitive letter matching' {
        It 'Should match lowercase key event for a sub with no modifiers' {
            $sub   = New-TeaKeySub -Key 'Q' -Handler { 'Quit' }
            $queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $queue.Enqueue([PSCustomObject]@{ Type = 'KeyDown'; Key = [System.ConsoleKey]::Q; Char = [char]0; Modifiers = [System.ConsoleModifiers]0 })
            $state  = @{}
            $result = @(Invoke-TeaSubscriptions -Subscriptions @($sub) -InputQueue $queue -TimerState $state)
            $result.Count | Should -Be 1
        }

        It 'Should match uppercase (Shift+letter) key event for a sub with no modifiers' {
            $sub   = New-TeaKeySub -Key 'Q' -Handler { 'Quit' }
            $queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $queue.Enqueue([PSCustomObject]@{ Type = 'KeyDown'; Key = [System.ConsoleKey]::Q; Char = [char]0; Modifiers = [System.ConsoleModifiers]::Shift })
            $state  = @{}
            $result = @(Invoke-TeaSubscriptions -Subscriptions @($sub) -InputQueue $queue -TimerState $state)
            $result.Count | Should -Be 1
        }

        It 'Should NOT strip Shift when sub explicitly requests Shift modifier' {
            $sub   = New-TeaKeySub -Key 'Shift+Q' -Handler { 'ShiftQ' }
            $queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $queue.Enqueue([PSCustomObject]@{ Type = 'KeyDown'; Key = [System.ConsoleKey]::Q; Char = [char]0; Modifiers = [System.ConsoleModifiers]::Control })
            $state  = @{}
            $result = @(Invoke-TeaSubscriptions -Subscriptions @($sub) -InputQueue $queue -TimerState $state)
            $result.Count | Should -Be 0
        }
    }

    Context 'Key subscriptions - Ctrl modifier matching' {
        It 'Should match Ctrl+Q exactly' {
            $sub   = New-TeaKeySub -Key 'Ctrl+Q' -Handler { 'CtrlQuit' }
            $queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $queue.Enqueue([PSCustomObject]@{ Type = 'KeyDown'; Key = [System.ConsoleKey]::Q; Char = [char]0; Modifiers = [System.ConsoleModifiers]::Control })
            $state  = @{}
            $result = @(Invoke-TeaSubscriptions -Subscriptions @($sub) -InputQueue $queue -TimerState $state)
            $result.Count | Should -Be 1
            $result[0]    | Should -Be 'CtrlQuit'
        }

        It 'Should NOT match plain Q when sub requires Ctrl+Q' {
            $sub   = New-TeaKeySub -Key 'Ctrl+Q' -Handler { 'CtrlQuit' }
            $queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $queue.Enqueue([PSCustomObject]@{ Type = 'KeyDown'; Key = [System.ConsoleKey]::Q; Char = [char]0; Modifiers = [System.ConsoleModifiers]0 })
            $state  = @{}
            $result = @(Invoke-TeaSubscriptions -Subscriptions @($sub) -InputQueue $queue -TimerState $state)
            $result.Count | Should -Be 0
        }
    }

    Context 'Timer subscriptions' {
        It 'Should NOT fire timer when interval has not elapsed' {
            $sub    = New-TeaTimerSub -IntervalMs 60000 -Handler { 'Tick' }
            $queue  = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $state  = @{}
            $result = @(Invoke-TeaSubscriptions -Subscriptions @($sub) -InputQueue $queue -TimerState $state)
            $result.Count | Should -Be 0
        }

        It 'Should fire timer when state shows interval elapsed' {
            $sub    = New-TeaTimerSub -IntervalMs 1000 -Handler { 'Tick' }
            $queue  = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $state  = @{ 'Timer:1000' = ([System.Environment]::TickCount - 2000) }
            $result = @(Invoke-TeaSubscriptions -Subscriptions @($sub) -InputQueue $queue -TimerState $state)
            $result.Count | Should -Be 1
            $result[0]    | Should -Be 'Tick'
        }

        It 'Should update TimerState after firing' {
            $sub    = New-TeaTimerSub -IntervalMs 1000 -Handler { 'Tick' }
            $queue  = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $before = [System.Environment]::TickCount
            $state  = @{ 'Timer:1000' = ($before - 2000) }
            $null   = @(Invoke-TeaSubscriptions -Subscriptions @($sub) -InputQueue $queue -TimerState $state)
            $state['Timer:1000'] | Should -BeGreaterOrEqual $before
        }

        It 'Should NOT fire timer twice in the same call' {
            $sub    = New-TeaTimerSub -IntervalMs 1000 -Handler { 'Tick' }
            $queue  = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $state  = @{ 'Timer:1000' = ([System.Environment]::TickCount - 2000) }
            $result = @(Invoke-TeaSubscriptions -Subscriptions @($sub) -InputQueue $queue -TimerState $state)
            $result.Count | Should -Be 1
        }

        It 'Should suppress null timer handler results' {
            $sub    = New-TeaTimerSub -IntervalMs 1000 -Handler { $null }
            $queue  = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $state  = @{ 'Timer:1000' = ([System.Environment]::TickCount - 2000) }
            $result = @(Invoke-TeaSubscriptions -Subscriptions @($sub) -InputQueue $queue -TimerState $state)
            $result.Count | Should -Be 0
        }
    }

    Context 'Mixed key and timer subscriptions' {
        It 'Should return both a timer message and a key message in the same call' {
            $timerSub = New-TeaTimerSub -IntervalMs 1000 -Handler { 'Tick' }
            $keySub   = New-TeaKeySub   -Key 'Q' -Handler { 'Quit' }
            $queue    = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $queue.Enqueue([PSCustomObject]@{ Type = 'KeyDown'; Key = [System.ConsoleKey]::Q; Char = [char]0; Modifiers = [System.ConsoleModifiers]0 })
            $state    = @{ 'Timer:1000' = ([System.Environment]::TickCount - 2000) }
            $result   = @(Invoke-TeaSubscriptions -Subscriptions @($timerSub, $keySub) -InputQueue $queue -TimerState $state)
            $result.Count | Should -Be 2
            $result        | Should -Contain 'Tick'
            $result        | Should -Contain 'Quit'
        }
    }

    Context 'Legacy Tick message pass-through' {
        It 'Should forward Tick messages from -TickMs runspace' {
            $queue  = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $queue.Enqueue([PSCustomObject]@{ Type = 'Tick'; Key = 'Tick' })
            $state  = @{}
            $result = @(Invoke-TeaSubscriptions -Subscriptions @() -InputQueue $queue -TimerState $state)
            $result.Count   | Should -Be 1
            $result[0].Type | Should -Be 'Tick'
        }
    }

    Context 'Queue draining' {
        It 'Should drain all pending items in one call' {
            $queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            1..5 | ForEach-Object {
                $queue.Enqueue([PSCustomObject]@{ Type = 'KeyDown'; Key = [System.ConsoleKey]::A; Char = [char]0; Modifiers = [System.ConsoleModifiers]0 })
            }
            $state  = @{}
            $result = @(Invoke-TeaSubscriptions -Subscriptions @() -InputQueue $queue -TimerState $state)
            $result.Count | Should -Be 5
        }

        It 'Should leave queue empty after call' {
            $queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            $queue.Enqueue([PSCustomObject]@{ Type = 'KeyDown'; Key = [System.ConsoleKey]::A; Char = [char]0; Modifiers = [System.ConsoleModifiers]0 })
            $state = @{}
            $null  = @(Invoke-TeaSubscriptions -Subscriptions @() -InputQueue $queue -TimerState $state)
            $queue.Count | Should -Be 0
        }
    }
}
