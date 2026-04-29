#Requires -Version 5.1
<#
.SYNOPSIS
    B-03: Increment/Decrement — first interactive PSTea program.

.DESCRIPTION
    Demonstrates:
      - $msg.Key switch pattern in Update
      - Constructing a new model instead of mutating the existing one
      - The default branch (required to avoid null-return errors)
      - String interpolation in View

    Keys:
      Up   - increment counter
      Down - decrement counter (can go negative)
      Q    - quit

.NOTES
    Run from the repo root:
        pwsh docs/tutorial/beginner/03-increment-decrement.ps1

    Compare with Examples/Invoke-IncrementDecrement.ps1 for the canonical 30-line version.
#>

if (-not (Get-Module PSTea)) { Import-Module "$PSScriptRoot/../../../PSTea.psd1" }

# ---------------------------------------------------------------------------
# MODEL
# ---------------------------------------------------------------------------
# Count : the integer being incremented/decremented (starts at 0, can go negative)
# ---------------------------------------------------------------------------

$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{ Count = 0 }
        Cmd   = $null
    }
}

# ---------------------------------------------------------------------------
# UPDATE
# ---------------------------------------------------------------------------

$updateFn = {
    param($msg, $model)

    switch ($msg.Key) {
        'UpArrow' {
            # Construct a new model — do not mutate $model.Count in place.
            [PSCustomObject]@{
                Model = [PSCustomObject]@{ Count = $model.Count + 1 }
                Cmd   = $null
            }
        }
        'DownArrow' {
            [PSCustomObject]@{
                Model = [PSCustomObject]@{ Count = $model.Count - 1 }
                Cmd   = $null
            }
        }
        'Q' {
            [PSCustomObject]@{
                Model = $model
                Cmd   = [PSCustomObject]@{ Type = 'Quit' }
            }
        }
        default {
            # NOTE: Required — all unhandled keys pass through here.
            # Without this, unhandled keys return $null, causing an event loop error.
            [PSCustomObject]@{ Model = $model; Cmd = $null }
        }
    }
}

# ---------------------------------------------------------------------------
# VIEW
# ---------------------------------------------------------------------------

$viewFn = {
    param($model)

    $hintStyle = New-TeaStyle -Foreground 'BrightBlack'

    New-TeaBox -Style (New-TeaStyle -Width 32 -Padding @(0, 1)) -Children @(
        New-TeaText -Content "Count: $($model.Count)"
        New-TeaText -Content '[Up] inc  [Down] dec  [Q] quit' -Style $hintStyle
    )
}

# ---------------------------------------------------------------------------
# RUN
# ---------------------------------------------------------------------------

Start-TeaProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn
