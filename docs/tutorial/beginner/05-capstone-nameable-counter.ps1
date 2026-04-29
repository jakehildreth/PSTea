#Requires -Version 5.1
<#
.SYNOPSIS
    B-05 Capstone: Nameable Counter — mode-based interactive app.

.DESCRIPTION
    Combines B-01 through B-04:
      - Four-field model with a mode flag (Editing)
      - Mode-guarded Update: editing mode intercepts all keys for text input
      - $msg.Char for character capture; $msg.Key for control keys
      - Conditional View rendering based on current mode
      - Full styling: Rounded border, BrightCyan name, BrightWhite count

    Keys (normal mode):
      Up      - increment count
      Down    - decrement count
      E       - enter rename mode
      Q       - quit (returns final model)

    Keys (rename mode):
      Printable chars  - append to NameDraft
      Backspace        - delete last character of NameDraft
      Enter            - confirm name (commits NameDraft to Name)
      Escape           - cancel (discards NameDraft)

.NOTES
    Run from the repo root:
        pwsh docs/tutorial/beginner/05-capstone-nameable-counter.ps1
#>

if (-not (Get-Module PSTea)) { Import-Module "$PSScriptRoot/../../../PSTea.psd1" }

# ---------------------------------------------------------------------------
# MODEL
# ---------------------------------------------------------------------------
# Name      : display name, editable at runtime
# Count     : current integer value
# Editing   : mode flag — $true while rename is in progress
# NameDraft : text accumulated during rename mode
# ---------------------------------------------------------------------------

$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Name      = 'My Counter'
            Count     = 0
            Editing   = $false
            NameDraft = ''
        }
        Cmd = $null
    }
}

# ---------------------------------------------------------------------------
# UPDATE
# ---------------------------------------------------------------------------

$updateFn = {
    param($msg, $model)

    # -------------------------------------------------------------------
    # EDITING MODE: intercept all keys for text input
    # Q, Up, Down, etc. are just characters here — do NOT quit.
    # -------------------------------------------------------------------
    if ($model.Editing) {
        switch ($msg.Key) {
            'Enter' {
                # Confirm: if draft is non-empty, use it; otherwise keep old name.
                $confirmedName = if ($model.NameDraft.Trim() -ne '') {
                    $model.NameDraft
                } else {
                    $model.Name
                }
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Name      = $confirmedName
                        Count     = $model.Count
                        Editing   = $false
                        NameDraft = ''
                    }
                    Cmd = $null
                }
            }
            'Escape' {
                # Cancel: discard draft, keep old name unchanged.
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Name      = $model.Name
                        Count     = $model.Count
                        Editing   = $false
                        NameDraft = ''
                    }
                    Cmd = $null
                }
            }
            'Backspace' {
                # Delete the last typed character from the draft.
                $draft = if ($model.NameDraft.Length -gt 0) {
                    $model.NameDraft.Substring(0, $model.NameDraft.Length - 1)
                } else {
                    ''
                }
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Name      = $model.Name
                        Count     = $model.Count
                        Editing   = $true
                        NameDraft = $draft
                    }
                    Cmd = $null
                }
            }
            default {
                # Any printable character: append to draft.
                # NOTE: use $msg.Char, not $msg.Key — Key is uppercase-only.
                if (-not [char]::IsControl($msg.Char) -and $msg.Char -ne [char]0) {
                    return [PSCustomObject]@{
                        Model = [PSCustomObject]@{
                            Name      = $model.Name
                            Count     = $model.Count
                            Editing   = $true
                            NameDraft = $model.NameDraft + [string]$msg.Char
                        }
                        Cmd = $null
                    }
                }
                # Non-printable unhandled key: pass through unchanged.
                return [PSCustomObject]@{ Model = $model; Cmd = $null }
            }
        }
    }

    # -------------------------------------------------------------------
    # NORMAL MODE: counting and mode entry
    # -------------------------------------------------------------------
    switch ($msg.Key) {
        'UpArrow' {
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Name      = $model.Name
                    Count     = $model.Count + 1
                    Editing   = $false
                    NameDraft = ''
                }
                Cmd = $null
            }
        }
        'DownArrow' {
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Name      = $model.Name
                    Count     = $model.Count - 1
                    Editing   = $false
                    NameDraft = ''
                }
                Cmd = $null
            }
        }
        'E' {
            # Enter rename mode. NameDraft starts empty — user types a fresh name.
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Name      = $model.Name
                    Count     = $model.Count
                    Editing   = $true
                    NameDraft = ''
                }
                Cmd = $null
            }
        }
        'Q' {
            # Q only quits in normal mode. In editing mode, Q is handled above as a
            # printable character that appends 'q' to NameDraft.
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

    $nameStyle  = New-TeaStyle -Foreground 'BrightCyan'   -Bold
    $countStyle = New-TeaStyle -Foreground 'BrightWhite'  -Bold
    $editStyle  = New-TeaStyle -Foreground 'BrightYellow'
    $hintStyle  = New-TeaStyle -Foreground 'BrightBlack'
    $boxStyle   = New-TeaStyle -Border 'Rounded' -Padding @(0, 2) -Width 40

    if ($model.Editing) {
        # Editing mode: show the in-progress draft with a blinking-cursor underscore.
        New-TeaBox -Style $boxStyle -Children @(
            New-TeaText -Content $model.Name                          -Style $nameStyle
            New-TeaText -Content "  $($model.Count)"                  -Style $countStyle
            New-TeaText -Content ''
            New-TeaText -Content "New name: $($model.NameDraft)_"     -Style $editStyle
            New-TeaText -Content ''
            New-TeaText -Content '[Enter] confirm  [Esc] cancel  [Backspace] delete' -Style $hintStyle
        )
    } else {
        # Normal mode.
        New-TeaBox -Style $boxStyle -Children @(
            New-TeaText -Content $model.Name                          -Style $nameStyle
            New-TeaText -Content "  $($model.Count)"                  -Style $countStyle
            New-TeaText -Content ''
            New-TeaText -Content '[Up] inc  [Down] dec  [E] rename  [Q] quit' -Style $hintStyle
        )
    }
}

# ---------------------------------------------------------------------------
# RUN
# ---------------------------------------------------------------------------

$finalModel = Start-TeaProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn
Write-Host "Final state: $($finalModel.Name) = $($finalModel.Count)"
