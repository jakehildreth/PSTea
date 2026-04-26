Import-Module "$PSScriptRoot/../Elm.psd1" -Force

# ---------------------------------------------------------------------------
# Stopwatch demo
# Start/stop with Space, record lap splits with L, reset with R.
# Demonstrates: tick-driven state updates, time formatting, variable-length lists
# ---------------------------------------------------------------------------

function Format-ElapsedTime {
    param([long]$Ms)
    $totalSec = [Math]::Floor($Ms / 1000)
    $minutes  = [Math]::Floor($totalSec / 60)
    $seconds  = $totalSec % 60
    $centis   = [int][Math]::Floor(($Ms % 1000) / 10)
    '{0:D2}:{1:D2}.{2:D2}' -f [int]$minutes, [int]$seconds, $centis
}

function Get-NowMs {
    [long]([DateTime]::UtcNow - [DateTime]::new(1970, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)).TotalMilliseconds
}

$init = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Running      = $false
            StartedAtMs  = 0L
            AccumulatedMs = 0L
            Laps         = @()
        }
        Cmd = $null
    }
}

$update = {
    param($msg, $model)

    switch ($msg.Key) {
        'Tick' {
            if (-not $model.Running) {
                return [PSCustomObject]@{ Model = $model; Cmd = $null }
            }
            $nowMs    = Get-NowMs
            $newAccum = [long]$model.AccumulatedMs + ($nowMs - [long]$model.StartedAtMs)
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Running       = $true
                    StartedAtMs   = $nowMs
                    AccumulatedMs = $newAccum
                    Laps          = $model.Laps
                }
                Cmd = $null
            }
        }
        'Spacebar' {
            if ($model.Running) {
                $nowMs      = Get-NowMs
                $finalAccum = [long]$model.AccumulatedMs + ($nowMs - [long]$model.StartedAtMs)
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Running       = $false
                        StartedAtMs   = 0L
                        AccumulatedMs = $finalAccum
                        Laps          = $model.Laps
                    }
                    Cmd = $null
                }
            } else {
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Running       = $true
                        StartedAtMs   = (Get-NowMs)
                        AccumulatedMs = [long]$model.AccumulatedMs
                        Laps          = $model.Laps
                    }
                    Cmd = $null
                }
            }
        }
        'L' {
            if (-not $model.Running) {
                return [PSCustomObject]@{ Model = $model; Cmd = $null }
            }
            $nowMs    = Get-NowMs
            $lapTotal = [long]$model.AccumulatedMs + ($nowMs - [long]$model.StartedAtMs)
            $newLaps  = @($model.Laps) + @($lapTotal)
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Running       = $true
                    StartedAtMs   = $nowMs
                    AccumulatedMs = $lapTotal
                    Laps          = $newLaps
                }
                Cmd = $null
            }
        }
        'R' {
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Running       = $false
                    StartedAtMs   = 0L
                    AccumulatedMs = 0L
                    Laps          = @()
                }
                Cmd = $null
            }
        }
        'Q' {
            return [PSCustomObject]@{
                Model = $model
                Cmd   = [PSCustomObject]@{ Type = 'Quit' }
            }
        }
    }

    [PSCustomObject]@{ Model = $model; Cmd = $null }
}

$view = {
    param($model)

    $titleStyle = New-ElmStyle -Foreground 'BrightCyan' -Bold
    $timeStyle  = New-ElmStyle -Foreground 'BrightWhite' -Bold
    $runStyle   = New-ElmStyle -Foreground 'BrightGreen'
    $pauseStyle = New-ElmStyle -Foreground 'BrightYellow'
    $lapStyle   = New-ElmStyle -Foreground 'BrightBlack'
    $hintStyle  = New-ElmStyle -Foreground 'BrightBlack'
    $boxStyle   = New-ElmStyle -Border 'Rounded' -Padding @(0, 2)

    $displayTime = Format-ElapsedTime -Ms $model.AccumulatedMs

    $statusNode = if ($model.Running) {
        New-ElmText -Content '[+] Running' -Style $runStyle
    } else {
        New-ElmText -Content '[i] Paused ' -Style $pauseStyle
    }

    $children = @(
        New-ElmText -Content 'Stopwatch' -Style $titleStyle
        New-ElmText -Content ''
        New-ElmText -Content $displayTime -Style $timeStyle
        $statusNode
        New-ElmText -Content ''
    )

    $laps = @($model.Laps)
    if ($laps.Count -gt 0) {
        $children += New-ElmText -Content 'Laps:' -Style $lapStyle
        $lapStart = [Math]::Max(0, $laps.Count - 8)
        for ($i = $lapStart; $i -lt $laps.Count; $i++) {
            $total   = $laps[$i]
            $lapTime = if ($i -gt 0) { $total - $laps[$i - 1] } else { $total }
            $children += New-ElmText -Content "  $($i + 1). $(Format-ElapsedTime -Ms $total)  (lap: $(Format-ElapsedTime -Ms $lapTime))" -Style $lapStyle
        }
        $children += New-ElmText -Content ''
    }

    $children += New-ElmText -Content '[Space] start/stop  [L] lap  [R] reset  [Q] quit' -Style $hintStyle

    New-ElmBox -Style $boxStyle -Children $children
}

Start-ElmProgram -InitFn $init -UpdateFn $update -ViewFn $view -TickMs 100
