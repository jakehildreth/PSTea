#Requires -Version 5.1
<#
.SYNOPSIS
    I-04: Focus and Forms — two-field form with Tab-based focus cycling.

.DESCRIPTION
    Demonstrates:
      - Focus field in model routing events to the active control
      - Tab key cycling focus between fields (Name → Subscribed → Name)
      - Conditional New-TeaCharSub: only active when Name has focus
      - New-TeaTextInput with FocusedBoxStyle to visually mark the active field
      - Manual checkbox: '[ ] Subscribe' / '[x] Subscribe' toggled by Space

    Fields:
      Name       - text input with cursor movement
      Subscribed - boolean checkbox toggled by Space

    Keys:
      Tab         - cycle focus to next field
      (Name field)
        Printable - insert character
        Backspace - delete before cursor
        Left/Right - move cursor
      (Subscribed field)
        Space     - toggle checkbox
      Q           - quit (returns final model)

.NOTES
    Run from the repo root:
        pwsh docs/tutorial/intermediate/04-focus-and-forms.ps1
#>

if (-not (Get-Module PSTea)) { Import-Module "$PSScriptRoot/../../../PSTea.psd1" }

# ---------------------------------------------------------------------------
# MODEL
# ---------------------------------------------------------------------------
# Focus      : 'Name' | 'Subscribed' — which field has keyboard focus
# Name       : text value of the name field
# NameCursor : cursor position within Name
# Subscribed : boolean state of the checkbox
# ---------------------------------------------------------------------------

$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Focus      = 'Name'
            Name       = ''
            NameCursor = 0
            Subscribed = $false
        }
        Cmd = $null
    }
}

# ---------------------------------------------------------------------------
# SUBSCRIPTIONS
# ---------------------------------------------------------------------------
# The char sub is added ONLY when the Name field has focus.
# When Subscribed has focus, printable keys do nothing.
# ---------------------------------------------------------------------------

$subscriptionFn = {
    param($model)
    $subs = @(
        New-TeaKeySub -Key 'Tab'        -Handler { 'Tab' }
        New-TeaKeySub -Key 'Spacebar'   -Handler { 'Toggle' }
        New-TeaKeySub -Key 'Backspace'  -Handler { 'DeleteBefore' }
        New-TeaKeySub -Key 'LeftArrow'  -Handler { 'CursorLeft' }
        New-TeaKeySub -Key 'RightArrow' -Handler { 'CursorRight' }
        New-TeaKeySub -Key 'Home'       -Handler { 'CursorHome' }
        New-TeaKeySub -Key 'End'        -Handler { 'CursorEnd' }
        New-TeaKeySub -Key 'Q'          -Handler { 'Quit' }
    )
    # Only capture printable characters when Name field is focused
    if ($model.Focus -eq 'Name') {
        $subs += New-TeaCharSub -Handler { param($e) "Char:$([string]$e.Char)" }
    }
    $subs
}

# ---------------------------------------------------------------------------
# UPDATE
# ---------------------------------------------------------------------------

$updateFn = {
    param($msg, $model)

    $n = $model.Name
    $c = $model.NameCursor

    # --- Checkbox toggle: only acts when Subscribed field is focused ---
    if ($msg -eq 'Toggle' -and $model.Focus -eq 'Subscribed') {
        return [PSCustomObject]@{
            Model = [PSCustomObject]@{
                Focus      = $model.Focus
                Name       = $n
                NameCursor = $c
                Subscribed = -not $model.Subscribed
            }
            Cmd = $null
        }
    }

    # --- Text input: only acts when Name field is focused ---
    if ($model.Focus -eq 'Name') {
        switch -Wildcard ($msg) {
            'Char:*' {
                $ch     = $msg.Substring(5)
                $before = $n.Substring(0, $c)
                $after  = $n.Substring($c)
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Focus      = $model.Focus
                        Name       = $before + $ch + $after
                        NameCursor = $c + 1
                        Subscribed = $model.Subscribed
                    }
                    Cmd = $null
                }
            }
            'DeleteBefore' {
                if ($c -gt 0) {
                    $newN = $n.Substring(0, $c - 1) + $n.Substring($c)
                    return [PSCustomObject]@{
                        Model = [PSCustomObject]@{
                            Focus      = $model.Focus
                            Name       = $newN
                            NameCursor = $c - 1
                            Subscribed = $model.Subscribed
                        }
                        Cmd = $null
                    }
                }
                return [PSCustomObject]@{ Model = $model; Cmd = $null }
            }
            'CursorLeft' {
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Focus      = $model.Focus
                        Name       = $n
                        NameCursor = [Math]::Max(0, $c - 1)
                        Subscribed = $model.Subscribed
                    }
                    Cmd = $null
                }
            }
            'CursorRight' {
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Focus      = $model.Focus
                        Name       = $n
                        NameCursor = [Math]::Min($n.Length, $c + 1)
                        Subscribed = $model.Subscribed
                    }
                    Cmd = $null
                }
            }
            'CursorHome' {
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Focus      = $model.Focus
                        Name       = $n
                        NameCursor = 0
                        Subscribed = $model.Subscribed
                    }
                    Cmd = $null
                }
            }
            'CursorEnd' {
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Focus      = $model.Focus
                        Name       = $n
                        NameCursor = $n.Length
                        Subscribed = $model.Subscribed
                    }
                    Cmd = $null
                }
            }
        }
    }

    # --- Global keys ---
    switch ($msg) {
        'Tab' {
            $nextFocus = switch ($model.Focus) {
                'Name'        { 'Subscribed' }
                'Subscribed'  { 'Name' }
                default       { 'Name' }
            }
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Focus      = $nextFocus
                    Name       = $n
                    NameCursor = $c
                    Subscribed = $model.Subscribed
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

    $hintStyle   = New-TeaStyle -Foreground 'BrightBlack'
    $labelStyle  = New-TeaStyle -Foreground 'BrightCyan'
    $boxStyle    = New-TeaStyle -Border 'Rounded' -Padding @(0, 2) -Width 42

    $nameFocused = $model.Focus -eq 'Name'

    # Name field: show focused border when active
    $nameInput = New-TeaTextInput `
        -Value           $model.Name `
        -CursorPos       $model.NameCursor `
        -Focused:$nameFocused `
        -Placeholder     'Your name...' `
        -FocusedStyle    (New-TeaStyle -Foreground 'BrightWhite') `
        -FocusedBoxStyle (New-TeaStyle -Border 'Rounded' -Foreground 'BrightCyan')

    # Checkbox: bold + bright when focused
    $checkFocused   = $model.Focus -eq 'Subscribed'
    $checkText      = if ($model.Subscribed) { '[x] Subscribe to updates' } else { '[ ] Subscribe to updates' }
    $checkStyle     = if ($checkFocused) {
        New-TeaStyle -Foreground 'BrightWhite' -Bold
    } else {
        New-TeaStyle -Foreground 'White'
    }

    # Focus indicator lines
    $nameLabel  = if ($nameFocused)  { New-TeaText -Content 'Name *'            -Style $labelStyle } `
                  else               { New-TeaText -Content 'Name'              -Style (New-TeaStyle -Foreground 'BrightBlack') }
    $checkLabel = if ($checkFocused) { New-TeaText -Content 'Options *'         -Style $labelStyle } `
                  else               { New-TeaText -Content 'Options'           -Style (New-TeaStyle -Foreground 'BrightBlack') }

    New-TeaBox -Style $boxStyle -Children @(
        New-TeaText -Content 'Contact Form' -Style (New-TeaStyle -Foreground 'BrightWhite' -Bold)
        New-TeaText -Content ''
        $nameLabel
        $nameInput
        New-TeaText -Content ''
        $checkLabel
        New-TeaText -Content $checkText -Style $checkStyle
        New-TeaText -Content ''
        New-TeaText -Content '[Tab] next field  [Space] toggle checkbox  [Q] quit' -Style $hintStyle
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

$sub = if ($result.Subscribed) { 'yes' } else { 'no' }
Write-Host "Name: $($result.Name)  |  Subscribed: $sub"
