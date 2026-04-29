#Requires -Version 5.1
<#
.SYNOPSIS
    A-03: Timer-Driven UIs — live clock + spinner with pause/resume.

.DESCRIPTION
    Demonstrates:
      - Two simultaneous New-TeaTimerSub at different intervals
      - Fast timer (80ms) for spinner animation via Frame counter
      - Slow timer (1000ms) for clock text update
      - Running flag for pause/resume of both timers together
      - ElapsedSeconds counter (independent of wall-clock time)
      - Conditional View: paused/running states with different colors and hints
      - New-TeaSpinner Braille variant

    Keys:
      Space  - pause / resume
      R      - reset elapsed seconds (clock continues)
      Q      - quit

.NOTES
    Run from the repo root:
        pwsh docs/tutorial/advanced/03-timer-driven-uis.ps1
#>

if (-not (Get-Module PSTea)) { Import-Module "$PSScriptRoot/../../../PSTea.psd1" }

# ---------------------------------------------------------------------------
# MODEL
# ---------------------------------------------------------------------------

$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Running        = $true
            Frame          = 0
            ClockText      = [datetime]::Now.ToString('HH:mm:ss')
            ElapsedSeconds = 0
        }
        Cmd = $null
    }
}

# ---------------------------------------------------------------------------
# SUBSCRIPTIONS
# ---------------------------------------------------------------------------

$subscriptionFn = {
    param($model)
    $subs = @(
        New-TeaKeySub -Key 'Spacebar' -Handler { 'Toggle' }
        New-TeaKeySub -Key 'R'        -Handler { 'ResetSeconds' }
        New-TeaKeySub -Key 'Q'        -Handler { 'Quit' }
    )
    if ($model.Running) {
        # Fast timer: drives spinner animation
        $subs += New-TeaTimerSub -IntervalMs 80   -Handler { 'Frame' }
        # Slow timer: updates clock text and increments elapsed counter
        $subs += New-TeaTimerSub -IntervalMs 1000 -Handler { 'Clock' }
    }
    $subs
}

# ---------------------------------------------------------------------------
# UPDATE
# ---------------------------------------------------------------------------

$updateFn = {
    param($msg, $model)

    switch ($msg) {
        'Frame' {
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Running        = $model.Running
                    Frame          = $model.Frame + 1
                    ClockText      = $model.ClockText
                    ElapsedSeconds = $model.ElapsedSeconds
                }
                Cmd = $null
            }
        }
        'Clock' {
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Running        = $model.Running
                    Frame          = $model.Frame
                    ClockText      = [datetime]::Now.ToString('HH:mm:ss')
                    ElapsedSeconds = $model.ElapsedSeconds + 1
                }
                Cmd = $null
            }
        }
        'Toggle' {
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Running        = -not $model.Running
                    Frame          = $model.Frame
                    ClockText      = $model.ClockText
                    ElapsedSeconds = $model.ElapsedSeconds
                }
                Cmd = $null
            }
        }
        'ResetSeconds' {
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Running        = $model.Running
                    Frame          = $model.Frame
                    ClockText      = $model.ClockText
                    ElapsedSeconds = 0
                }
                Cmd = $null
            }
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

# ---------------------------------------------------------------------------
# VIEW
# ---------------------------------------------------------------------------

$viewFn = {
    param($model)

    $hintStyle    = New-TeaStyle -Foreground 'BrightBlack'
    $clockStyle   = New-TeaStyle -Foreground 'BrightWhite' -Bold
    $spinnerStyle = New-TeaStyle -Foreground 'BrightCyan'

    $statusColor = if ($model.Running) { 'BrightGreen' } else { 'BrightYellow' }
    $statusText  = if ($model.Running) { 'Running' }     else { 'Paused' }
    $spaceHint   = if ($model.Running) { '[Space] pause' } else { '[Space] resume' }

    New-TeaBox -Style (New-TeaStyle -Border 'Rounded' -Padding @(1, 3) -Width 36) -Children @(
        New-TeaRow -Children @(
            New-TeaSpinner -Frame $model.Frame -Variant 'Braille' -Style $spinnerStyle
            New-TeaText    -Content "  $($model.ClockText)"       -Style $clockStyle
        )
        New-TeaText -Content ''
        New-TeaText -Content "Elapsed: $($model.ElapsedSeconds)s"
        New-TeaText -Content $statusText -Style (New-TeaStyle -Foreground $statusColor)
        New-TeaText -Content ''
        New-TeaText -Content "$spaceHint  [R] reset  [Q] quit" -Style $hintStyle
    )
}

# ---------------------------------------------------------------------------
# RUN
# ---------------------------------------------------------------------------

Start-TeaProgram `
    -InitFn         $initFn `
    -UpdateFn       $updateFn `
    -ViewFn         $viewFn `
    -SubscriptionFn $subscriptionFn
