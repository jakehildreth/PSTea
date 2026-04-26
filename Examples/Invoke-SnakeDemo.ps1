Import-Module "$PSScriptRoot/../Elm.psd1" -Force

# ---------------------------------------------------------------------------
# Snake demo
# Classic Snake game in the terminal.
# Demonstrates: timer + key subscriptions together, game loop state, grid render.
#
# Controls:
#   Arrow keys / WASD  - change direction
#   Space              - start / pause
#   R                  - restart
#   Q                  - quit
# ---------------------------------------------------------------------------

$script:COLS  = 30   # playfield columns (each cell = 1 char)
$script:ROWS  = 18   # playfield rows
$script:SPEED = 150  # ms per tick

function Get-RandomFood {
    param([object[]]$Snake)
    $occupied = @{}
    foreach ($seg in $Snake) { $occupied["$($seg.X),$($seg.Y)"] = $true }
    $free = [System.Collections.Generic.List[object]]::new()
    for ($y = 0; $y -lt $script:ROWS; $y++) {
        for ($x = 0; $x -lt $script:COLS; $x++) {
            if (-not $occupied.ContainsKey("$x,$y")) {
                $free.Add([PSCustomObject]@{ X = $x; Y = $y })
            }
        }
    }
    if ($free.Count -eq 0) { return $null }
    $free[(Get-Random -Maximum $free.Count)]
}

function New-SnakeModel {
    $head = [PSCustomObject]@{ X = 14; Y = 9 }
    $body = @(
        [PSCustomObject]@{ X = 13; Y = 9 }
        [PSCustomObject]@{ X = 12; Y = 9 }
    )
    $snake = @($head) + $body
    [PSCustomObject]@{
        Snake     = $snake
        Dir       = 'Right'
        NextDir   = 'Right'
        Food      = (Get-RandomFood -Snake $snake)
        Score     = 0
        Running   = $false
        GameOver  = $false
    }
}

$initFn = {
    [PSCustomObject]@{
        Model = New-SnakeModel
        Cmd   = $null
    }
}

$updateFn = {
    param($msg, $model)

    switch ($msg) {
        'Tick' {
            if (-not $model.Running -or $model.GameOver) {
                return [PSCustomObject]@{ Model = $model; Cmd = $null }
            }

            $dir = $model.NextDir

            $snake = @($model.Snake)
            $head  = $snake[0]

            $newHead = switch ($dir) {
                'Up'    { [PSCustomObject]@{ X = $head.X;     Y = $head.Y - 1 } }
                'Down'  { [PSCustomObject]@{ X = $head.X;     Y = $head.Y + 1 } }
                'Left'  { [PSCustomObject]@{ X = $head.X - 1; Y = $head.Y     } }
                'Right' { [PSCustomObject]@{ X = $head.X + 1; Y = $head.Y     } }
            }

            # Wall collision
            $hitWall = ($newHead.X -lt 0 -or $newHead.X -ge $script:COLS -or
                        $newHead.Y -lt 0 -or $newHead.Y -ge $script:ROWS)

            # Self collision
            $hitSelf = $false
            foreach ($seg in $snake) {
                if ($seg.X -eq $newHead.X -and $seg.Y -eq $newHead.Y) {
                    $hitSelf = $true; break
                }
            }

            if ($hitWall -or $hitSelf) {
                $newModel = [PSCustomObject]@{
                    Snake    = $model.Snake
                    Dir      = $dir
                    NextDir  = $dir
                    Food     = $model.Food
                    Score    = $model.Score
                    Running  = $false
                    GameOver = $true
                }
                return [PSCustomObject]@{ Model = $newModel; Cmd = $null }
            }

            # Eat food?
            $ate      = ($null -ne $model.Food -and $newHead.X -eq $model.Food.X -and $newHead.Y -eq $model.Food.Y)
            $newSnake = if ($ate) {
                @($newHead) + $snake        # keep tail (grow)
            } else {
                @($newHead) + $snake[0..($snake.Count - 2)]  # drop tail
            }
            $newFood  = if ($ate) { Get-RandomFood -Snake $newSnake } else { $model.Food }
            $newScore = if ($ate) { $model.Score + 1 } else { $model.Score }

            $newModel = [PSCustomObject]@{
                Snake    = $newSnake
                Dir      = $dir
                NextDir  = $dir
                Food     = $newFood
                Score    = $newScore
                Running  = $true
                GameOver = $false
            }
            return [PSCustomObject]@{ Model = $newModel; Cmd = $null }
        }

        'Up'    { $opp = 'Down'  }
        'Down'  { $opp = 'Up'    }
        'Left'  { $opp = 'Right' }
        'Right' { $opp = 'Left'  }
    }

    # Direction change (only if not opposite to current)
    if ($msg -in @('Up','Down','Left','Right')) {
        $opp = switch ($msg) {
            'Up'    { 'Down'  }
            'Down'  { 'Up'    }
            'Left'  { 'Right' }
            'Right' { 'Left'  }
        }
        if ($model.Dir -ne $opp) {
            $newModel = [PSCustomObject]@{
                Snake    = $model.Snake
                Dir      = $model.Dir
                NextDir  = $msg
                Food     = $model.Food
                Score    = $model.Score
                Running  = $model.Running
                GameOver = $model.GameOver
            }
            return [PSCustomObject]@{ Model = $newModel; Cmd = $null }
        }
        return [PSCustomObject]@{ Model = $model; Cmd = $null }
    }

    switch ($msg) {
        'Toggle' {
            if ($model.GameOver) {
                return [PSCustomObject]@{ Model = $model; Cmd = $null }
            }
            $newModel = [PSCustomObject]@{
                Snake    = $model.Snake
                Dir      = $model.Dir
                NextDir  = $model.NextDir
                Food     = $model.Food
                Score    = $model.Score
                Running  = -not $model.Running
                GameOver = $model.GameOver
            }
            return [PSCustomObject]@{ Model = $newModel; Cmd = $null }
        }
        'Restart' {
            return [PSCustomObject]@{ Model = (New-SnakeModel); Cmd = $null }
        }
        'Quit' {
            return [PSCustomObject]@{
                Model = $model
                Cmd   = [PSCustomObject]@{ Type = 'Quit' }
            }
        }
    }

    [PSCustomObject]@{ Model = $model; Cmd = $null }
}

$viewFn = {
    param($model)

    $snake  = @($model.Snake)
    $snakeSet = @{}
    foreach ($seg in $snake) { $snakeSet["$($seg.X),$($seg.Y)"] = $true }

    # Build the grid as rows of text
    $headStyle  = New-ElmStyle -Foreground 'BrightGreen'  -Bold
    $bodyStyle  = New-ElmStyle -Foreground 'Green'
    $foodStyle  = New-ElmStyle -Foreground 'BrightRed'    -Bold
    $wallStyle  = New-ElmStyle -Foreground 'BrightBlack'
    $titleStyle = New-ElmStyle -Foreground 'BrightCyan'   -Bold
    $scoreStyle = New-ElmStyle -Foreground 'BrightWhite'
    $hintStyle  = New-ElmStyle -Foreground 'BrightBlack'
    $deadStyle  = New-ElmStyle -Foreground 'BrightRed'    -Bold

    $head = $snake[0]
    $border = '+' + ('-' * $script:COLS) + '+'

    $children = [System.Collections.Generic.List[object]]::new()
    $children.Add((New-ElmText -Content 'Snake' -Style $titleStyle))
    $children.Add((New-ElmText -Content "Score: $($model.Score)" -Style $scoreStyle))
    $children.Add((New-ElmText -Content $border -Style $wallStyle))

    for ($y = 0; $y -lt $script:ROWS; $y++) {
        $rowChars = [System.Text.StringBuilder]::new()
        $null = $rowChars.Append('|')
        for ($x = 0; $x -lt $script:COLS; $x++) {
            $key = "$x,$y"
            if ($x -eq $head.X -and $y -eq $head.Y) {
                $null = $rowChars.Append('@')
            } elseif ($snakeSet.ContainsKey($key)) {
                $null = $rowChars.Append('o')
            } elseif ($null -ne $model.Food -and $x -eq $model.Food.X -and $y -eq $model.Food.Y) {
                $null = $rowChars.Append('*')
            } else {
                $null = $rowChars.Append(' ')
            }
        }
        $null = $rowChars.Append('|')
        $children.Add((New-ElmText -Content $rowChars.ToString() -Style $wallStyle))
    }

    $children.Add((New-ElmText -Content $border -Style $wallStyle))

    if ($model.GameOver) {
        $children.Add((New-ElmText -Content '' ))
        $children.Add((New-ElmText -Content "GAME OVER  Score: $($model.Score)" -Style $deadStyle))
        $children.Add((New-ElmText -Content '[R] Restart   [Q] Quit' -Style $hintStyle))
    } elseif ($model.Running) {
        $children.Add((New-ElmText -Content '[Arrow/WASD] steer   [Space] pause   [Q] quit' -Style $hintStyle))
    } else {
        $children.Add((New-ElmText -Content '[Space] Start   [Q] Quit' -Style $hintStyle))
    }

    New-ElmBox -Children $children.ToArray()
}

$subFn = {
    param($model)
    $subs = [System.Collections.Generic.List[object]]::new()

    # Quit always works
    $subs.Add((New-ElmKeySub -Key 'Q' -Handler { 'Quit' }))

    if ($model.GameOver) {
        $subs.Add((New-ElmKeySub -Key 'R' -Handler { 'Restart' }))
    } else {
        $subs.Add((New-ElmKeySub -Key 'Space'    -Handler { 'Toggle'  }))
        $subs.Add((New-ElmKeySub -Key 'R'        -Handler { 'Restart' }))
        $subs.Add((New-ElmKeySub -Key 'UpArrow'  -Handler { 'Up'      }))
        $subs.Add((New-ElmKeySub -Key 'DownArrow' -Handler { 'Down'   }))
        $subs.Add((New-ElmKeySub -Key 'LeftArrow' -Handler { 'Left'   }))
        $subs.Add((New-ElmKeySub -Key 'RightArrow' -Handler { 'Right' }))
        $subs.Add((New-ElmKeySub -Key 'W' -Handler { 'Up'    }))
        $subs.Add((New-ElmKeySub -Key 'S' -Handler { 'Down'  }))
        $subs.Add((New-ElmKeySub -Key 'A' -Handler { 'Left'  }))
        $subs.Add((New-ElmKeySub -Key 'D' -Handler { 'Right' }))

        if ($model.Running) {
            $subs.Add((New-ElmTimerSub -IntervalMs $script:SPEED -Handler { 'Tick' }))
        }
    }

    return $subs.ToArray()
}

function Invoke-SnakeDemo {
    <#
    .SYNOPSIS
        Classic Snake game in the terminal.

    .DESCRIPTION
        Arrow keys / WASD to steer. Space to start/pause. R to restart. Q to quit.
        Demonstrates combined timer + key subscriptions in the Elm architecture.

    .NOTES
        Requires the Elm module and a terminal at least 32 columns wide.
        Run from Examples: . .\Invoke-SnakeDemo.ps1; Invoke-SnakeDemo
    #>
    [CmdletBinding()]
    param()

    Start-ElmProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -SubscriptionFn $subFn
}

Invoke-SnakeDemo
