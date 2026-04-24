#Requires -Version 5.1
<#
.SYNOPSIS
    Pomodoro countdown timer demo — showcases the subscription system.

.DESCRIPTION
    A 25-minute countdown timer demonstrating conditional subscriptions:
    the timer subscription is only active when the clock is running,
    so pausing it literally removes the sub from the subscription list.

    Keys:
      Space  — toggle start/pause
      R      — reset to 25:00
      Q      — quit

.NOTES
    Requires the Elm module to be loaded.
    Run from the Examples directory: . .\Invoke-PomodoroDemo.ps1; Invoke-PomodoroDemo
#>
function Invoke-PomodoroDemo {
    [CmdletBinding()]
    param()

    Import-Module "$PSScriptRoot/../Elm.psd1" -Force

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

        $titleStyle  = New-ElmStyle -Foreground 'Cyan'    -Bold
        $clockStyle  = New-ElmStyle -Foreground 'White'   -Bold
        $phaseStyle  = New-ElmStyle -Foreground $(if ($model.Phase -eq 'Work') { 'Red' } else { 'Green' })
        $barStyle    = New-ElmStyle -Foreground 'BrightBlack'
        $hintStyle   = New-ElmStyle -Foreground 'BrightBlack'
        $stateStyle  = New-ElmStyle -Foreground $(if ($model.Running) { 'Green' } else { 'Yellow' })

        New-ElmBox -Children @(
            New-ElmText -Content '  Pomodoro Timer  ' -Style $titleStyle
            New-ElmText -Content ''
            New-ElmText -Content "  $phaseLabel  " -Style $phaseStyle
            New-ElmText -Content "  $clock  " -Style $clockStyle
            New-ElmText -Content "  $bar  " -Style $barStyle
            New-ElmText -Content "  $stateLabel  " -Style $stateStyle
            New-ElmText -Content ''
            New-ElmText -Content "  $toggleLabel   [R] Reset   [Q] Quit  " -Style $hintStyle
        )
    }

    # ---------------------------------------------------------- Subscriptions
    # The timer sub is only active when Running is true — pausing removes it.
    $subFn = {
        param($model)
        $subs = [System.Collections.Generic.List[object]]::new()
        $subs.Add((New-ElmKeySub -Key 'Q'     -Handler { 'Quit'   }))
        $subs.Add((New-ElmKeySub -Key 'Space' -Handler { 'Toggle' }))
        $subs.Add((New-ElmKeySub -Key 'R'     -Handler { 'Reset'  }))
        if ($model.Running) {
            $subs.Add((New-ElmTimerSub -IntervalMs 1000 -Handler { 'Tick' }))
        }
        return $subs.ToArray()
    }

    Start-ElmProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -SubscriptionFn $subFn
}

Invoke-PomodoroDemo
