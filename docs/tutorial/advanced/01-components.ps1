#Requires -Version 5.1
<#
.SYNOPSIS
    A-01: Components — two counters side by side with Tab-based focus.

.DESCRIPTION
    Demonstrates:
      - Component pattern: PSCustomObject with Init, Update, View scriptblocks
      - Component Update returns sub-model directly (no {Model;Cmd} wrapper)
      - New-TeaComponent: embed a component in the parent view tree
      - New-TeaComponentMsg: route a message to a specific component by ID
      - Parent Update: switch on $msg.Type -eq 'ComponentMsg', dispatch by ComponentId
      - Tab-based focus: 'Active' field in parent model tracks which component is focused
      - & $scriptblock $arg1 $arg2 syntax for invoking stored scriptblocks

    Two counters side by side. Focused counter has a BrightCyan border.

    Keys:
      Tab        - switch focus between left and right counters
      Up arrow   - increment the focused counter
      Down arrow - decrement the focused counter
      Q          - quit

.NOTES
    Run from the repo root:
        pwsh docs/tutorial/advanced/01-components.ps1
#>

if (-not (Get-Module PSTea)) { Import-Module "$PSScriptRoot/../../../PSTea.psd1" }

# ---------------------------------------------------------------------------
# COMPONENT DEFINITION
# ---------------------------------------------------------------------------
# A component is a hashtable (or PSCustomObject) with Init, Update, and View.
# Init    : returns the initial sub-model
# Update  : param($msg, $subModel) → new sub-model (NO {Model;Cmd} wrapper)
# View    : param($subModel) → ViewNode
# ---------------------------------------------------------------------------

$counterComponent = @{
    Init = {
        [PSCustomObject]@{ Count = 0; Active = $false }
    }

    Update = {
        param($msg, $subModel)
        switch ($msg) {
            'Increment'  { [PSCustomObject]@{ Count = $subModel.Count + 1; Active = $subModel.Active } }
            'Decrement'  { [PSCustomObject]@{ Count = $subModel.Count - 1; Active = $subModel.Active } }
            'Activate'   { [PSCustomObject]@{ Count = $subModel.Count;     Active = $true } }
            'Deactivate' { [PSCustomObject]@{ Count = $subModel.Count;     Active = $false } }
            'Reset'      { [PSCustomObject]@{ Count = 0;                   Active = $subModel.Active } }
            default      { $subModel }
        }
    }

    View = {
        param($subModel)
        $borderColor = if ($subModel.Active) { 'BrightCyan' } else { 'BrightBlack' }
        $boxStyle    = New-TeaStyle -Border 'Rounded' -Width 20 -Padding @(0, 2) -Foreground $borderColor
        $countStyle  = New-TeaStyle -Foreground 'BrightWhite' -Bold

        New-TeaBox -Style $boxStyle -Children @(
            New-TeaText -Content "Count: $($subModel.Count)" -Style $countStyle
            New-TeaText -Content (if ($subModel.Active) { '(focused)' } else { '' }) `
                        -Style (New-TeaStyle -Foreground 'BrightCyan')
        )
    }
}

# ---------------------------------------------------------------------------
# MODEL
# ---------------------------------------------------------------------------
# Left, Right: sub-models for each component instance
# Active: 'left' | 'right' — which component has keyboard focus
# ---------------------------------------------------------------------------

$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Left   = & $using:counterComponent.Init
            Right  = (& $using:counterComponent.Init | ForEach-Object { [PSCustomObject]@{ Count = 0; Active = $false } })
            Active = 'left'
        } | ForEach-Object {
            # Activate the initially focused component
            $_.Left = & $using:counterComponent.Update 'Activate' $_.Left
            $_
        }
        Cmd = $null
    }
}

# ---------------------------------------------------------------------------
# SUBSCRIPTIONS
# ---------------------------------------------------------------------------

$subscriptionFn = {
    param($model)
    $active = $model.Active
    @(
        New-TeaKeySub -Key 'Tab' -Handler { 'SwitchFocus' }
        New-TeaKeySub -Key 'UpArrow' -Handler {
            New-TeaComponentMsg -ComponentId $using:active -Msg 'Increment'
        }
        New-TeaKeySub -Key 'DownArrow' -Handler {
            New-TeaComponentMsg -ComponentId $using:active -Msg 'Decrement'
        }
        New-TeaKeySub -Key 'R' -Handler {
            New-TeaComponentMsg -ComponentId $using:active -Msg 'Reset'
        }
        New-TeaKeySub -Key 'Q' -Handler { 'Quit' }
    )
}

# ---------------------------------------------------------------------------
# UPDATE
# ---------------------------------------------------------------------------

$updateFn = {
    param($msg, $model)

    # --- Route ComponentMsg to the correct component ---
    if ($msg.Type -eq 'ComponentMsg') {
        $id       = $msg.ComponentId
        $innerMsg = $msg.Msg

        $newLeft  = $model.Left
        $newRight = $model.Right

        if ($id -eq 'left') {
            $newLeft  = & $using:counterComponent.Update $innerMsg $model.Left
        }
        if ($id -eq 'right') {
            $newRight = & $using:counterComponent.Update $innerMsg $model.Right
        }

        return [PSCustomObject]@{
            Model = [PSCustomObject]@{ Left = $newLeft; Right = $newRight; Active = $model.Active }
            Cmd   = $null
        }
    }

    # --- Global messages ---
    switch ($msg) {
        'SwitchFocus' {
            $nextActive = if ($model.Active -eq 'left') { 'right' } else { 'left' }
            # Deactivate both, then activate the new one
            $newLeft  = & $using:counterComponent.Update 'Deactivate' $model.Left
            $newRight = & $using:counterComponent.Update 'Deactivate' $model.Right
            if ($nextActive -eq 'left') {
                $newLeft  = & $using:counterComponent.Update 'Activate' $newLeft
            } else {
                $newRight = & $using:counterComponent.Update 'Activate' $newRight
            }
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{ Left = $newLeft; Right = $newRight; Active = $nextActive }
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
    $hintStyle = New-TeaStyle -Foreground 'BrightBlack'
    $total     = $model.Left.Count + $model.Right.Count

    New-TeaBox -Children @(
        New-TeaRow -Children @(
            New-TeaComponent -ComponentId 'left'  -SubModel $model.Left  -ViewFn $using:counterComponent.View
            New-TeaComponent -ComponentId 'right' -SubModel $model.Right -ViewFn $using:counterComponent.View
        )
        New-TeaText -Content ''
        New-TeaText -Content "Total: $total" -Style (New-TeaStyle -Foreground 'BrightWhite')
        New-TeaText -Content ''
        New-TeaText -Content '[Tab] switch focus  [Up/Down] inc/dec  [R] reset  [Q] quit' -Style $hintStyle
    )
}

# ---------------------------------------------------------------------------
# RUN
# ---------------------------------------------------------------------------

$result = Start-TeaProgram `
    -InitFn         $initFn `
    -UpdateFn       $updateFn `
    -ViewFn         $viewFn `
    -SubscriptionFn $subscriptionFn

Write-Host "Left: $($result.Left.Count)  Right: $($result.Right.Count)"
