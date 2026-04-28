#Requires -Version 5.1
<#
.SYNOPSIS
    Pomodoro countdown timer demo - showcases the subscription system.

.DESCRIPTION
    A 25-minute countdown timer demonstrating conditional subscriptions:
    the timer subscription is only active when the clock is running,
    so pausing it literally removes the sub from the subscription list.

    Keys:
      Space  - toggle start/pause
      R      - reset to 25:00
      Q      - quit

.NOTES
    Requires the PSTea module to be loaded.
    Run from the Examples directory: . .\Invoke-PomodoroDemo.ps1; Invoke-PomodoroDemo
#>
function Invoke-PomodoroDemo {
    [CmdletBinding()]
    param()

    Import-Module "$PSScriptRoot/../PSTea.psd1" -Force

    # ------------------------------------------------------------------ Model
    # SecondsLeft : [int]  remaining seconds (0..1500)
    # Running     : [bool] whether the clock is ticking
    # Phase       : [string] 'Work' or 'Break'
    # ------------------------------------------------------------------ Model

    $initFn = {
        [PSCustomObject]@{
            Model = [PSCustomObject]@{
                SecondsLeft = 1500
                Running     = $false
                Phase       = 'Work'
            }
            Cmd = $null
        }
    }

    # ----------------------------------------------------------------- Update
    $updateFn = {
        param($msg, $model)
        switch ($msg) {
            'Tick' {
                $newSecs = $model.SecondsLeft - 1
                if ($newSecs -le 0) {
                    # Switch phases
                    $nextPhase = if ($model.Phase -eq 'Work') { 'Break' } else { 'Work' }
                    $nextSecs  = if ($nextPhase -eq 'Work') { 1500 } else { 300 }
                    $newModel  = [PSCustomObject]@{
                        SecondsLeft = $nextSecs
                        Running     = $false
                        Phase       = $nextPhase
                    }
                    return [PSCustomObject]@{ Model = $newModel; Cmd = $null }
                }
                $newModel = [PSCustomObject]@{
                    SecondsLeft = $newSecs
                    Running     = $model.Running
                    Phase       = $model.Phase
                }
                return [PSCustomObject]@{ Model = $newModel; Cmd = $null }
            }
            'Toggle' {
                $newModel = [PSCustomObject]@{
                    SecondsLeft = $model.SecondsLeft
                    Running     = -not $model.Running
                    Phase       = $model.Phase
                }
                return [PSCustomObject]@{ Model = $newModel; Cmd = $null }
            }
            'Reset' {
                $newModel = [PSCustomObject]@{
                    SecondsLeft = 1500
                    Running     = $false
                    Phase       = 'Work'
                }
                return [PSCustomObject]@{ Model = $newModel; Cmd = $null }
            }
            'Quit' {
                return [PSCustomObject]@{
                    Model = $model
                    Cmd   = [PSCustomObject]@{ Type = 'Quit' }
                }
            }
            default {
                return [PSCustomObject]@{ Model = $model; Cmd = $null }
            }
        }
    }

    # ------------------------------------------------------------------- View
    $viewFn = {
        param($model)

        $mins  = [int][math]::Floor($model.SecondsLeft / 60)
        $secs  = $model.SecondsLeft % 60
        $clock = '{0:D2}:{1:D2}' -f $mins, $secs

        $phaseLabel  = if ($model.Phase -eq 'Work') { 'Work' } else { 'Break' }
        $stateLabel  = if ($model.Running) { 'running' } else { 'paused' }
        $toggleLabel = if ($model.Running) { '[Space] Pause' } else { '[Space] Start' }

        # Progress bar (40 chars wide)
        $total      = if ($model.Phase -eq 'Work') { 1500 } else { 300 }
        $filled     = [int][math]::Floor(($total - $model.SecondsLeft) / $total * 40)
        $empty      = 40 - $filled
        $bar        = ('[') + ([string]'#' * $filled) + ([string]'-' * $empty) + (']')

        $titleStyle  = New-TeaStyle -Foreground 'Cyan'    -Bold
        $clockStyle  = New-TeaStyle -Foreground 'White'   -Bold
        $phaseStyle  = New-TeaStyle -Foreground $(if ($model.Phase -eq 'Work') { 'Red' } else { 'Green' })
        $barStyle    = New-TeaStyle -Foreground 'BrightBlack'
        $hintStyle   = New-TeaStyle -Foreground 'BrightBlack'
        $stateStyle  = New-TeaStyle -Foreground $(if ($model.Running) { 'Green' } else { 'Yellow' })

        New-TeaBox -Children @(
            New-TeaText -Content '  Pomodoro Timer  ' -Style $titleStyle
            New-TeaText -Content ''
            New-TeaText -Content "  $phaseLabel  " -Style $phaseStyle
            New-TeaText -Content "  $clock  " -Style $clockStyle
            New-TeaText -Content "  $bar  " -Style $barStyle
            New-TeaText -Content "  $stateLabel  " -Style $stateStyle
            New-TeaText -Content ''
            New-TeaText -Content "  $toggleLabel   [R] Reset   [Q] Quit  " -Style $hintStyle
        )
    }

    # ---------------------------------------------------------- Subscriptions
    # The timer sub is only active when Running is true - pausing removes it.
    $subFn = {
        param($model)
        $subs = [System.Collections.Generic.List[object]]::new()
        $subs.Add((New-TeaKeySub -Key 'Q'     -Handler { 'Quit'   }))
        $subs.Add((New-TeaKeySub -Key 'Space' -Handler { 'Toggle' }))
        $subs.Add((New-TeaKeySub -Key 'R'     -Handler { 'Reset'  }))
        if ($model.Running) {
            $subs.Add((New-TeaTimerSub -IntervalMs 1000 -Handler { 'Tick' }))
        }
        return $subs.ToArray()
    }

    Start-TeaProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -SubscriptionFn $subFn
}

Invoke-PomodoroDemo
