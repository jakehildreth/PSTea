#Requires -Version 5.1
<#
.SYNOPSIS
    I-02: Lists and Navigation — navigable color picker using New-TeaList.

.DESCRIPTION
    Demonstrates:
      - New-TeaList: Items, SelectedIndex, MaxVisible, SelectedStyle
      - Cursor tracking in model; UpArrow/DownArrow subscriptions
      - Wrap-around navigation: ($cursor + 1) % $count
      - Accessing the selected item: $model.Items[$model.Cursor]
      - New-TeaRow for side-by-side list + detail panel
      - Using the selected color name as both $style value and display text

    Shows all 16 named PSTea colors. Selected item renders in its own color.

    Keys:
      Up    - move selection up (wraps)
      Down  - move selection down (wraps)
      Q     - quit

.NOTES
    Run from the repo root:
        pwsh docs/tutorial/intermediate/02-lists-and-navigation.ps1
#>

if (-not (Get-Module PSTea)) { Import-Module "$PSScriptRoot/../../../PSTea.psd1" }

# ---------------------------------------------------------------------------
# DATA
# ---------------------------------------------------------------------------
# Defined outside scriptblocks. Reference inside with $using:colors.
# ---------------------------------------------------------------------------

$colors = @(
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
            Items  = $using:colors
            Cursor = 0
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
        New-TeaKeySub -Key 'UpArrow'   -Handler { 'MoveUp' }
        New-TeaKeySub -Key 'DownArrow' -Handler { 'MoveDown' }
        New-TeaKeySub -Key 'Q'         -Handler { 'Quit' }
    )
}

# ---------------------------------------------------------------------------
# UPDATE
# ---------------------------------------------------------------------------

$updateFn = {
    param($msg, $model)
    $count = $model.Items.Count

    switch ($msg) {
        'MoveUp' {
            # NOTE: The + $count prevents a negative modulus result when cursor = 0.
            $prev = ($model.Cursor - 1 + $count) % $count
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{ Items = $model.Items; Cursor = $prev }
                Cmd   = $null
            }
        }
        'MoveDown' {
            $next = ($model.Cursor + 1) % $count
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{ Items = $model.Items; Cursor = $next }
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

    $selected     = $model.Items[$model.Cursor]
    $selStyle     = New-TeaStyle -Foreground $selected -Bold
    $hintStyle    = New-TeaStyle -Foreground 'BrightBlack'
    $previewStyle = New-TeaStyle -Foreground $selected -Bold

    New-TeaBox -Children @(
        New-TeaRow -Children @(
            # Left: the scrollable list
            New-TeaBox -Style (New-TeaStyle -Border 'Rounded' -Width 22 -Padding @(0, 1)) -Children @(
                New-TeaList `
                    -Items         $model.Items `
                    -SelectedIndex $model.Cursor `
                    -MaxVisible    8 `
                    -SelectedStyle $selStyle
            )
            # Right: detail panel showing the selected color name in its own color
            New-TeaBox -Style (New-TeaStyle -Border 'Rounded' -Width 26 -MarginLeft 2 -Padding @(1, 2)) -Children @(
                New-TeaText -Content 'Selected color:'
                New-TeaText -Content $selected    -Style $previewStyle
                New-TeaText -Content ''
                New-TeaText -Content "Index: $($model.Cursor + 1) / $($model.Items.Count)" -Style (New-TeaStyle -Foreground 'BrightBlack')
            )
        )
        New-TeaText -Content ''
        New-TeaText -Content '[Up/Down] navigate  [Q] quit' -Style $hintStyle
    )
}

# ---------------------------------------------------------------------------
# RUN
# ---------------------------------------------------------------------------

$result = Start-TeaProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -SubscriptionFn $subscriptionFn
Write-Host "You selected: $($result.Items[$result.Cursor])"
