Import-Module "$PSScriptRoot/../PSTea.psd1" -Force

# ---------------------------------------------------------------------------
# Component demo
# Two independent counters, each a self-contained component with its own
# model, update, and view. The parent routes ComponentMsg to each one.
# Demonstrates: New-TeaComponent, New-TeaComponentMsg, message routing
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Counter component definition
# A component is a plain PSCustomObject with Init, Update, and View scriptblocks
# ---------------------------------------------------------------------------

$Counter = [PSCustomObject]@{
    Init   = {
        param($Label)
        [PSCustomObject]@{ Label = $Label; Count = 0 }
    }
    Update = {
        param($msg, $model)
        switch ($msg.Type) {
            'Increment' { [PSCustomObject]@{ Label = $model.Label; Count = $model.Count + 1 } }
            'Decrement' { [PSCustomObject]@{ Label = $model.Label; Count = $model.Count - 1 } }
            default     { $model }
        }
    }
    View   = {
        param($model)
        $labelStyle = New-TeaStyle -Foreground 'BrightCyan' -Bold
        $countStyle = New-TeaStyle -Foreground 'BrightWhite'
        $boxStyle   = New-TeaStyle -Border 'Rounded' -Padding @(0, 2) -Width 24
        New-TeaBox -Style $boxStyle -Children @(
            New-TeaText -Content $model.Label -Style $labelStyle
            New-TeaText -Content "  $($model.Count)"  -Style $countStyle
        )
    }
}

# ---------------------------------------------------------------------------
# Parent Init
# ---------------------------------------------------------------------------

$init = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            LeftModel  = & $Counter.Init 'Left'
            RightModel = & $Counter.Init 'Right'
            Focus      = 'Left'   # which counter receives key input
        }
        Cmd = $null
    }
}

# ---------------------------------------------------------------------------
# Parent Update
# Routes ComponentMsg to the correct counter; Tab switches focus
# ---------------------------------------------------------------------------

$update = {
    param($msg, $model)

    # Tab key switches focus between counters
    if ($msg.Key -eq 'Tab') {
        $newFocus = if ($model.Focus -eq 'Left') { 'Right' } else { 'Left' }
        return [PSCustomObject]@{
            Model = [PSCustomObject]@{
                LeftModel  = $model.LeftModel
                RightModel = $model.RightModel
                Focus      = $newFocus
            }
            Cmd = $null
        }
    }

    if ($msg.Key -eq 'Q') {
        return [PSCustomObject]@{
            Model = $model
            Cmd   = [PSCustomObject]@{ Type = 'Quit' }
        }
    }

    # Route Up/Down to the focused counter as component messages
    $innerMsg = switch ($msg.Key) {
        'UpArrow'   { [PSCustomObject]@{ Type = 'Increment' } }
        'DownArrow' { [PSCustomObject]@{ Type = 'Decrement' } }
        default     { $null }
    }

    if ($null -eq $innerMsg) {
        return [PSCustomObject]@{ Model = $model; Cmd = $null }
    }

    $newLeft  = $model.LeftModel
    $newRight = $model.RightModel

    if ($model.Focus -eq 'Left') {
        $newLeft  = & $Counter.Update $innerMsg $model.LeftModel
    } else {
        $newRight = & $Counter.Update $innerMsg $model.RightModel
    }

    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            LeftModel  = $newLeft
            RightModel = $newRight
            Focus      = $model.Focus
        }
        Cmd = $null
    }
}

# ---------------------------------------------------------------------------
# Parent View
# Embeds each counter as a New-TeaComponent node
# ---------------------------------------------------------------------------

$view = {
    param($model)

    $hintStyle      = New-TeaStyle -Foreground 'BrightBlack'
    $focusLabelStyle = New-TeaStyle -Foreground 'BrightYellow' -Bold

    $focusText = "Focus: $($model.Focus)"

    $leftComponent  = New-TeaComponent -ComponentId 'left'  -SubModel $model.LeftModel  -ViewFn $Counter.View
    $rightComponent = New-TeaComponent -ComponentId 'right' -SubModel $model.RightModel -ViewFn $Counter.View

    New-TeaBox -Children @(
        New-TeaText -Content 'Component Demo' -Style (New-TeaStyle -Bold -Foreground 'BrightWhite')
        New-TeaText -Content ''
        New-TeaRow -Children @($leftComponent, (New-TeaText -Content '  '), $rightComponent)
        New-TeaText -Content ''
        New-TeaText -Content $focusText -Style $focusLabelStyle
        New-TeaText -Content '[Up] inc  [Down] dec  [Tab] switch  [Q] quit' -Style $hintStyle
    )
}

Start-TeaProgram -InitFn $init -UpdateFn $update -ViewFn $view
