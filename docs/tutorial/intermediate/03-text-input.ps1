#Requires -Version 5.1
<#
.SYNOPSIS
    I-03: Text Input — live color filter using New-TeaCharSub + New-TeaTextInput.

.DESCRIPTION
    Demonstrates:
      - New-TeaCharSub: fires for any printable char not consumed by a key sub
      - Combining New-TeaCharSub with New-TeaKeySub (key subs take priority)
      - Value + CursorPos model fields for a movable text cursor
      - Inserting, deleting, and cursor movement in Update
      - New-TeaTextInput view widget
      - switch -Wildcard for 'Char:*' message routing

    Type to filter the 16 named colors. Cursor movement and deletion supported.

    Keys:
      Printable chars - insert at cursor
      Backspace       - delete before cursor
      Delete          - delete at cursor
      Left / Right    - move cursor
      Home            - cursor to start
      End             - cursor to end
      Escape          - clear input
      Q               - quit (key sub takes priority over char sub)

.NOTES
    Run from the repo root:
        pwsh docs/tutorial/intermediate/03-text-input.ps1
#>

if (-not (Get-Module PSTea)) { Import-Module "$PSScriptRoot/../../../PSTea.psd1" }

# ---------------------------------------------------------------------------
# DATA
# ---------------------------------------------------------------------------

$allColors = @(
    'Black', 'Red', 'Green', 'Yellow',
    'Blue', 'Magenta', 'Cyan', 'White',
    'BrightBlack', 'BrightRed', 'BrightGreen', 'BrightYellow',
    'BrightBlue', 'BrightMagenta', 'BrightCyan', 'BrightWhite'
)

# ---------------------------------------------------------------------------
# MODEL
# ---------------------------------------------------------------------------

$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Input     = ''
            CursorPos = 0
            Colors    = $using:allColors
        }
        Cmd = $null
    }
}

# ---------------------------------------------------------------------------
# SUBSCRIPTIONS
# ---------------------------------------------------------------------------

$subscriptionFn = {
    param($model)
    @(
        New-TeaKeySub -Key 'Escape'     -Handler { 'Clear' }
        New-TeaKeySub -Key 'Backspace'  -Handler { 'DeleteBefore' }
        New-TeaKeySub -Key 'Delete'     -Handler { 'DeleteAfter' }
        New-TeaKeySub -Key 'LeftArrow'  -Handler { 'CursorLeft' }
        New-TeaKeySub -Key 'RightArrow' -Handler { 'CursorRight' }
        New-TeaKeySub -Key 'Home'       -Handler { 'CursorHome' }
        New-TeaKeySub -Key 'End'        -Handler { 'CursorEnd' }
        # Q as explicit key sub takes priority — pressing Q quits, does NOT type 'q'
        New-TeaKeySub -Key 'Q'          -Handler { 'Quit' }
        # Everything else falls through here
        New-TeaCharSub -Handler { param($e) "Char:$([string]$e.Char)" }
    )
}

# ---------------------------------------------------------------------------
# UPDATE
# ---------------------------------------------------------------------------

$updateFn = {
    param($msg, $model)

    $v = $model.Input
    $c = $model.CursorPos

    # NOTE: switch -Wildcard enables 'Char:*' prefix matching.
    switch -Wildcard ($msg) {
        'Char:*' {
            # Extract the typed character from the message prefix
            $ch     = $msg.Substring(5)
            $before = $v.Substring(0, $c)
            $after  = $v.Substring($c)
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Input     = $before + $ch + $after
                    CursorPos = $c + 1
                    Colors    = $model.Colors
                }
                Cmd = $null
            }
        }
        'DeleteBefore' {
            if ($c -gt 0) {
                $newV = $v.Substring(0, $c - 1) + $v.Substring($c)
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{ Input = $newV; CursorPos = $c - 1; Colors = $model.Colors }
                    Cmd   = $null
                }
            }
            return [PSCustomObject]@{ Model = $model; Cmd = $null }
        }
        'DeleteAfter' {
            if ($c -lt $v.Length) {
                $newV = $v.Substring(0, $c) + $v.Substring($c + 1)
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{ Input = $newV; CursorPos = $c; Colors = $model.Colors }
                    Cmd   = $null
                }
            }
            return [PSCustomObject]@{ Model = $model; Cmd = $null }
        }
        'CursorLeft' {
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{ Input = $v; CursorPos = [Math]::Max(0, $c - 1); Colors = $model.Colors }
                Cmd   = $null
            }
        }
        'CursorRight' {
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{ Input = $v; CursorPos = [Math]::Min($v.Length, $c + 1); Colors = $model.Colors }
                Cmd   = $null
            }
        }
        'CursorHome' {
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{ Input = $v; CursorPos = 0; Colors = $model.Colors }
                Cmd   = $null
            }
        }
        'CursorEnd' {
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{ Input = $v; CursorPos = $v.Length; Colors = $model.Colors }
                Cmd   = $null
            }
        }
        'Clear' {
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{ Input = ''; CursorPos = 0; Colors = $model.Colors }
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
    $boxStyle  = New-TeaStyle -Border 'Rounded' -Width 34 -Padding @(0, 1)

    # Filter colors by current input (case-insensitive substring)
    $filter   = $model.Input
    $filtered = if ($filter -eq '') {
        $model.Colors
    } else {
        @($model.Colors | Where-Object { $_ -like "*$filter*" })
    }

    $countText = "$($filtered.Count) / $($model.Colors.Count) colors"

    $inputField = New-TeaTextInput `
        -Value        $model.Input `
        -CursorPos    $model.CursorPos `
        -Focused `
        -Placeholder  'Filter colors...' `
        -FocusedStyle (New-TeaStyle -Foreground 'BrightWhite')

    New-TeaBox -Children @(
        New-TeaBox -Style $boxStyle -Children @(
            $inputField
            New-TeaText -Content $countText -Style (New-TeaStyle -Foreground 'BrightBlack')
            New-TeaText -Content ''
            New-TeaList -Items ($filtered -as [string[]]) -MaxVisible 12
        )
        New-TeaText -Content ''
        New-TeaText -Content '[Type] filter  [Backspace/Del] delete  [←→ Home/End] cursor  [Esc] clear  [Q] quit' -Style $hintStyle
    )
}

# ---------------------------------------------------------------------------
# RUN
# ---------------------------------------------------------------------------

Start-TeaProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -SubscriptionFn $subscriptionFn
