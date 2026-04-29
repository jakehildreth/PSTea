#Requires -Version 5.1
<#
.SYNOPSIS
    I-01: Subscriptions — declarative key bindings and a live countdown timer.

.DESCRIPTION
    Demonstrates:
      - SubscriptionFn returning an array of subscription descriptors
      - New-TeaKeySub: bind a specific key to a named string message
      - New-TeaTimerSub: fire a message at a fixed millisecond interval
      - Conditional timer sub for pause/resume (include only when Running = $true)
      - switch ($msg) on plain string messages — NOT switch ($msg.Key)

    A 10-second countdown with pause/resume:
      Space  - toggle running/paused
      R      - reset to 10, paused
      Q      - quit

.NOTES
    Run from the repo root:
        pwsh docs/tutorial/intermediate/01-subscriptions.ps1
#>

if (-not (Get-Module PSTea)) { Import-Module "$PSScriptRoot/../../../PSTea.psd1" }

# ---------------------------------------------------------------------------
# MODEL
# ---------------------------------------------------------------------------
# TimeLeft : seconds remaining (counts down to zero)
# Running  : $true = timer active, $false = paused
# ---------------------------------------------------------------------------

$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            TimeLeft = 10
            Running  = $false   # starts paused so user can read the UI first
        }
        Cmd = $null
    }
}

# ---------------------------------------------------------------------------
# SUBSCRIPTIONS
# ---------------------------------------------------------------------------
# This scriptblock is called after every model update.
# It returns the CURRENT set of active subscriptions as an array.
# Subscriptions not in the array are inactive (paused).
# ---------------------------------------------------------------------------

$subscriptionFn = {
    param($model)

    $subs = @(
        New-TeaKeySub -Key 'Spacebar' -Handler { 'Toggle' }
        New-TeaKeySub -Key 'R'        -Handler { 'Reset' }
        New-TeaKeySub -Key 'Q'        -Handler { 'Quit' }
    )

    # Only add the timer when the countdown is active AND has time remaining.
    # When TimeLeft reaches 0, this condition is $false — timer stops automatically.
    if ($model.Running -and $model.TimeLeft -gt 0) {
        $subs += New-TeaTimerSub -IntervalMs 1000 -Handler { 'Tick' }
    }

    $subs
}

# ---------------------------------------------------------------------------
# UPDATE
# ---------------------------------------------------------------------------
# NOTE: $msg is the return value of the handler — a plain string like 'Tick'.
# Use switch ($msg), NOT switch ($msg.Key).
# ---------------------------------------------------------------------------

$updateFn = {
    param($msg, $model)

    switch ($msg) {
        'Tick' {
            $newTime = [Math]::Max(0, $model.TimeLeft - 1)
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{ TimeLeft = $newTime; Running = $model.Running }
                Cmd   = $null
            }
        }
        'Toggle' {
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{ TimeLeft = $model.TimeLeft; Running = -not $model.Running }
                Cmd   = $null
            }
        }
        'Reset' {
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{ TimeLeft = 10; Running = $false }
                Cmd   = $null
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

    $hintStyle  = New-TeaStyle -Foreground 'BrightBlack'
    $boxStyle   = New-TeaStyle -Border 'Rounded' -Padding @(0, 2) -Width 36

    $statusLine = if ($model.Running) {
        New-TeaText -Content 'Running...'  -Style (New-TeaStyle -Foreground 'BrightGreen')
    } else {
        New-TeaText -Content 'Paused'      -Style (New-TeaStyle -Foreground 'BrightYellow')
    }

    $timeColor = if ($model.TimeLeft -le 3) { 'BrightRed' } else { 'BrightWhite' }
    $timeLine  = New-TeaText -Content "  $($model.TimeLeft)s" -Style (New-TeaStyle -Foreground $timeColor -Bold)

    $spaceHint = if ($model.Running) { '[Space] pause' } else { '[Space] start' }

    New-TeaBox -Style $boxStyle -Children @(
        New-TeaText -Content 'Countdown'
        $timeLine
        $statusLine
        New-TeaText -Content ''
        New-TeaText -Content "$spaceHint  [R] reset  [Q] quit" -Style $hintStyle
    )
}

# ---------------------------------------------------------------------------
# RUN
# ---------------------------------------------------------------------------

Start-TeaProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -SubscriptionFn $subscriptionFn
