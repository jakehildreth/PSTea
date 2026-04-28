Import-Module "$PSScriptRoot/../PSTea.psd1" -Force

# ---------------------------------------------------------------------------
# 256-Color Palette picker demo
# Navigate the full 256-color ANSI palette with arrow keys.
# Demonstrates: dense grid rendering (256 nodes), integer 256-color styling,
# computed RGB info, purely key-driven state
# ---------------------------------------------------------------------------

function Get-ColorDescription {
    param([int]$Index)
    if ($Index -lt 16) {
        $names = @(
            'Black', 'Dark Red', 'Dark Green', 'Dark Yellow',
            'Dark Blue', 'Dark Magenta', 'Dark Cyan', 'Gray',
            'Dark Gray', 'Red', 'Green', 'Yellow',
            'Blue', 'Magenta', 'Cyan', 'White'
        )
        return "System: $($names[$Index])"
    } elseif ($Index -lt 232) {
        $n    = $Index - 16
        $b    = $n % 6
        $g    = [Math]::Floor($n / 6) % 6
        $r    = [Math]::Floor($n / 36)
        $rVal = if ($r -eq 0) { 0 } else { 55 + $r * 40 }
        $gVal = if ($g -eq 0) { 0 } else { 55 + $g * 40 }
        $bVal = if ($b -eq 0) { 0 } else { 55 + $b * 40 }
        return "RGB($rVal, $gVal, $bVal)"
    } else {
        $v = 8 + ($Index - 232) * 10
        return "Gray $v/255"
    }
}

$init = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{ CursorX = 0; CursorY = 0 }
        Cmd   = $null
    }
}

$update = {
    param($msg, $model)

    switch ($msg.Key) {
        'UpArrow' {
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{ CursorX = $model.CursorX; CursorY = [Math]::Max(0, $model.CursorY - 1) }
                Cmd   = $null
            }
        }
        'DownArrow' {
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{ CursorX = $model.CursorX; CursorY = [Math]::Min(15, $model.CursorY + 1) }
                Cmd   = $null
            }
        }
        'LeftArrow' {
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{ CursorX = [Math]::Max(0, $model.CursorX - 1); CursorY = $model.CursorY }
                Cmd   = $null
            }
        }
        'RightArrow' {
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{ CursorX = [Math]::Min(15, $model.CursorX + 1); CursorY = $model.CursorY }
                Cmd   = $null
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

    $titleStyle = New-TeaStyle -Foreground 'BrightCyan' -Bold
    $infoStyle  = New-TeaStyle -Foreground 'BrightWhite'
    $hintStyle  = New-TeaStyle -Foreground 'BrightBlack'
    $boxStyle   = New-TeaStyle -Border 'Rounded' -Padding @(0, 1)

    $selectedIndex = $model.CursorY * 16 + $model.CursorX

    # Build 16 rows of 16 colored cells (256 nodes total)
    $rows = @()
    for ($y = 0; $y -lt 16; $y++) {
        $cells = @()
        for ($x = 0; $x -lt 16; $x++) {
            $idx      = $y * 16 + $x
            $isCursor = ($x -eq $model.CursorX -and $y -eq $model.CursorY)
            if ($isCursor) {
                $cells += New-TeaText -Content '()' -Style (New-TeaStyle -Background $idx -Foreground 'White')
            } else {
                $cells += New-TeaText -Content '  ' -Style (New-TeaStyle -Background $idx)
            }
        }
        $rows += New-TeaRow -Children $cells
    }

    $colorDesc = Get-ColorDescription -Index $selectedIndex

    $children = @(
        New-TeaText -Content '256-Color Palette' -Style $titleStyle
        New-TeaText -Content ''
    )
    $children += $rows
    $children += New-TeaText -Content ''
    $children += New-TeaText -Content "Index: $selectedIndex   $colorDesc   ESC[48;5;${selectedIndex}m" -Style $infoStyle
    $children += New-TeaText -Content ''
    $children += New-TeaText -Content '[Arrow keys] navigate  [Q] quit' -Style $hintStyle

    New-TeaBox -Style $boxStyle -Children $children
}

Start-TeaProgram -InitFn $init -UpdateFn $update -ViewFn $view
