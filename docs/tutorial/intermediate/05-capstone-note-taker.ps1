#Requires -Version 5.1
<#
.SYNOPSIS
    I-05 Capstone: Note Taker — multi-note CRUD app with lists, text input, and focus.

.DESCRIPTION
    Combines I-01 through I-04:
      - New-TeaList for navigable note titles
      - Text input (New-TeaCharSub) for title editing and body editing
      - Three focus states: List, Body, EditTitle
      - Conditional subscriptions based on focus
      - Array immutability: map pattern for updating a note in the array
      - Double-press guard for delete (PendingDelete flag)
      - New-TeaRow two-column layout

    Keys (List focus):
      Up / Down  - navigate note list
      N          - new note (auto-enters EditTitle mode)
      E          - edit selected note title
      D          - delete selected note (press twice to confirm)
      Tab        - switch focus to Body
      Q          - quit, returns final notes array

    Keys (Body focus):
      Printable  - append to note body
      Backspace  - delete last body character
      Tab        - return focus to List

    Keys (EditTitle focus):
      Printable  - append to title draft
      Backspace  - delete last draft character
      Enter      - confirm title
      Escape     - cancel edit

.NOTES
    Run from the repo root:
        pwsh docs/tutorial/intermediate/05-capstone-note-taker.ps1
#>

if (-not (Get-Module PSTea)) { Import-Module "$PSScriptRoot/../../../PSTea.psd1" }

# ---------------------------------------------------------------------------
# MODEL
# ---------------------------------------------------------------------------

$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Notes         = @(
                [PSCustomObject]@{ Title = 'Welcome'; Body = 'Start typing in this note.' }
                [PSCustomObject]@{ Title = 'Ideas';   Body = '' }
            )
            Cursor        = 0
            Focus         = 'List'        # 'List' | 'Body' | 'EditTitle'
            TitleDraft    = ''
            PendingDelete = $false
        }
        Cmd = $null
    }
}

# ---------------------------------------------------------------------------
# SUBSCRIPTIONS
# ---------------------------------------------------------------------------

$subscriptionFn = {
    param($model)

    $subs = @(
        New-TeaKeySub -Key 'Tab' -Handler { 'Tab' }
        New-TeaKeySub -Key 'Q'   -Handler { 'Quit' }
    )

    switch ($model.Focus) {
        'List' {
            $subs += New-TeaKeySub -Key 'UpArrow'   -Handler { 'MoveUp' }
            $subs += New-TeaKeySub -Key 'DownArrow'  -Handler { 'MoveDown' }
            $subs += New-TeaKeySub -Key 'N'          -Handler { 'NewNote' }
            $subs += New-TeaKeySub -Key 'E'          -Handler { 'EditTitle' }
            $subs += New-TeaKeySub -Key 'D'          -Handler { 'Delete' }
        }
        'Body' {
            $subs += New-TeaKeySub -Key 'Backspace' -Handler { 'BodyBackspace' }
            $subs += New-TeaCharSub -Handler { param($e) "Char:$([string]$e.Char)" }
        }
        'EditTitle' {
            $subs += New-TeaKeySub -Key 'Enter'     -Handler { 'ConfirmTitle' }
            $subs += New-TeaKeySub -Key 'Escape'    -Handler { 'CancelTitle' }
            $subs += New-TeaKeySub -Key 'Backspace' -Handler { 'TitleBackspace' }
            $subs += New-TeaCharSub -Handler { param($e) "Char:$([string]$e.Char)" }
        }
    }

    $subs
}

# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------

function script:Update-NoteAt {
    param([array]$Notes, [int]$Index, [scriptblock]$Transform)
    $result = 0..($Notes.Count - 1) | ForEach-Object {
        if ($_ -eq $Index) { & $Transform $Notes[$_] } else { $Notes[$_] }
    }
    return @($result)
}

function script:New-NoteModel {
    param($Model, [hashtable]$Overrides)
    $props = @{
        Notes         = $Model.Notes
        Cursor        = $Model.Cursor
        Focus         = $Model.Focus
        TitleDraft    = $Model.TitleDraft
        PendingDelete = $Model.PendingDelete
    }
    foreach ($k in $Overrides.Keys) { $props[$k] = $Overrides[$k] }
    [PSCustomObject]$props
}

# ---------------------------------------------------------------------------
# UPDATE
# ---------------------------------------------------------------------------

$updateFn = {
    param($msg, $model)

    switch -Wildcard ($msg) {

        # --- Navigation ---
        'MoveUp' {
            $prev = [Math]::Max(0, $model.Cursor - 1)
            return [PSCustomObject]@{
                Model = script:New-NoteModel $model @{ Cursor = $prev; PendingDelete = $false }
                Cmd   = $null
            }
        }
        'MoveDown' {
            $next = [Math]::Min($model.Notes.Count - 1, $model.Cursor + 1)
            return [PSCustomObject]@{
                Model = script:New-NoteModel $model @{ Cursor = $next; PendingDelete = $false }
                Cmd   = $null
            }
        }

        # --- New note ---
        'NewNote' {
            $newNote  = [PSCustomObject]@{ Title = "Note $($model.Notes.Count + 1)"; Body = '' }
            $newNotes = @($model.Notes) + @($newNote)
            return [PSCustomObject]@{
                Model = script:New-NoteModel $model @{
                    Notes      = $newNotes
                    Cursor     = $newNotes.Count - 1
                    Focus      = 'EditTitle'
                    TitleDraft = $newNote.Title
                    PendingDelete = $false
                }
                Cmd = $null
            }
        }

        # --- Edit title ---
        'EditTitle' {
            return [PSCustomObject]@{
                Model = script:New-NoteModel $model @{
                    Focus      = 'EditTitle'
                    TitleDraft = $model.Notes[$model.Cursor].Title
                    PendingDelete = $false
                }
                Cmd = $null
            }
        }
        'ConfirmTitle' {
            $title = if ($model.TitleDraft.Trim() -ne '') { $model.TitleDraft } else {
                $model.Notes[$model.Cursor].Title
            }
            $updated = script:Update-NoteAt $model.Notes $model.Cursor {
                param($n) [PSCustomObject]@{ Title = $title; Body = $n.Body }
            }
            return [PSCustomObject]@{
                Model = script:New-NoteModel $model @{
                    Notes      = $updated
                    Focus      = 'List'
                    TitleDraft = ''
                    PendingDelete = $false
                }
                Cmd = $null
            }
        }
        'CancelTitle' {
            return [PSCustomObject]@{
                Model = script:New-NoteModel $model @{
                    Focus      = 'List'
                    TitleDraft = ''
                    PendingDelete = $false
                }
                Cmd = $null
            }
        }
        'TitleBackspace' {
            $d = $model.TitleDraft
            $newDraft = if ($d.Length -gt 0) { $d.Substring(0, $d.Length - 1) } else { '' }
            return [PSCustomObject]@{
                Model = script:New-NoteModel $model @{ TitleDraft = $newDraft }
                Cmd   = $null
            }
        }

        # --- Delete ---
        'Delete' {
            if (-not $model.PendingDelete) {
                # First press: arm the guard
                return [PSCustomObject]@{
                    Model = script:New-NoteModel $model @{ PendingDelete = $true }
                    Cmd   = $null
                }
            }
            # Second press: execute
            if ($model.Notes.Count -le 1) {
                # Refuse to delete the last note
                return [PSCustomObject]@{
                    Model = script:New-NoteModel $model @{ PendingDelete = $false }
                    Cmd   = $null
                }
            }
            $idx       = $model.Cursor
            $newNotes  = @($model.Notes | Where-Object { $_ -ne $model.Notes[$idx] })
            $newCursor = [Math]::Min($idx, $newNotes.Count - 1)
            return [PSCustomObject]@{
                Model = script:New-NoteModel $model @{
                    Notes         = $newNotes
                    Cursor        = $newCursor
                    Focus         = 'List'
                    TitleDraft    = ''
                    PendingDelete = $false
                }
                Cmd = $null
            }
        }

        # --- Body editing ---
        'Char:*' {
            $ch = $msg.Substring(5)
            if ($model.Focus -eq 'Body') {
                $updated = script:Update-NoteAt $model.Notes $model.Cursor {
                    param($n) [PSCustomObject]@{ Title = $n.Title; Body = $n.Body + $ch }
                }
                return [PSCustomObject]@{
                    Model = script:New-NoteModel $model @{ Notes = $updated; PendingDelete = $false }
                    Cmd   = $null
                }
            }
            if ($model.Focus -eq 'EditTitle') {
                return [PSCustomObject]@{
                    Model = script:New-NoteModel $model @{ TitleDraft = $model.TitleDraft + $ch }
                    Cmd   = $null
                }
            }
            return [PSCustomObject]@{ Model = $model; Cmd = $null }
        }
        'BodyBackspace' {
            $b = $model.Notes[$model.Cursor].Body
            if ($b.Length -gt 0) {
                $newBody = $b.Substring(0, $b.Length - 1)
                $updated = script:Update-NoteAt $model.Notes $model.Cursor {
                    param($n) [PSCustomObject]@{ Title = $n.Title; Body = $newBody }
                }
                return [PSCustomObject]@{
                    Model = script:New-NoteModel $model @{ Notes = $updated }
                    Cmd   = $null
                }
            }
            return [PSCustomObject]@{ Model = $model; Cmd = $null }
        }

        # --- Tab: cycle focus ---
        'Tab' {
            $nextFocus = switch ($model.Focus) {
                'List' { 'Body' }
                'Body' { 'List' }
                'EditTitle' { 'List' }   # Tab cancels edit — same as Escape
                default { 'List' }
            }
            return [PSCustomObject]@{
                Model = script:New-NoteModel $model @{
                    Focus         = $nextFocus
                    TitleDraft    = ''
                    PendingDelete = $false
                }
                Cmd = $null
            }
        }

        # --- Quit ---
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

    $hintStyle    = New-TeaStyle -Foreground 'BrightBlack'
    $titleStyle   = New-TeaStyle -Foreground 'BrightCyan'  -Bold
    $editStyle    = New-TeaStyle -Foreground 'BrightYellow'
    $warnStyle    = New-TeaStyle -Foreground 'BrightRed'
    $listFocused  = $model.Focus -eq 'List' -or $model.Focus -eq 'EditTitle'
    $bodyFocused  = $model.Focus -eq 'Body'

    $titles = @($model.Notes | ForEach-Object { $_.Title })
    $note   = $model.Notes[$model.Cursor]

    # List panel border highlights when focused
    $listBorderColor = if ($listFocused) { 'BrightCyan' } else { 'BrightBlack' }
    $listStyle       = New-TeaStyle -Border 'Rounded' -Width 24 -Padding @(0, 1) -Foreground $listBorderColor
    $listSelStyle    = New-TeaStyle -Foreground 'BrightCyan' -Bold

    # Body panel
    $bodyBorderColor = if ($bodyFocused) { 'BrightCyan' } else { 'BrightBlack' }
    $bodyStyle       = New-TeaStyle -Border 'Rounded' -Width 44 -MarginLeft 2 -Padding @(0, 1) -Foreground $bodyBorderColor

    # Title display (edit mode shows draft + cursor)
    $titleDisplay = if ($model.Focus -eq 'EditTitle') {
        New-TeaText -Content "$($model.TitleDraft)_" -Style $editStyle
    } else {
        New-TeaText -Content $note.Title -Style $titleStyle
    }

    # Body display
    $bodyContent = if ($bodyFocused) {
        New-TeaText -Content ($note.Body + '|')   # cursor indicator
    } else {
        New-TeaText -Content $note.Body
    }

    # Delete warning
    $deleteWarning = if ($model.PendingDelete) {
        New-TeaText -Content 'Press D again to confirm delete' -Style $warnStyle
    } else {
        New-TeaText -Content ''
    }

    # Hint line changes based on focus
    $hint = switch ($model.Focus) {
        'List'      { '[Up/Down] nav  [N] new  [E] edit  [D] delete  [Tab] body  [Q] quit' }
        'Body'      { '[Type] edit body  [Backspace] delete  [Tab] list  [Q] quit' }
        'EditTitle' { '[Type] edit title  [Enter] confirm  [Esc] cancel' }
    }

    New-TeaBox -Children @(
        New-TeaRow -Children @(
            New-TeaBox -Style $listStyle -Children @(
                New-TeaList -Items $titles -SelectedIndex $model.Cursor -MaxVisible 16 -SelectedStyle $listSelStyle
            )
            New-TeaBox -Style $bodyStyle -Children @(
                $titleDisplay
                New-TeaText -Content ''
                $bodyContent
                New-TeaText -Content ''
                $deleteWarning
            )
        )
        New-TeaText -Content ''
        New-TeaText -Content $hint -Style $hintStyle
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

Write-Host "`nFinal notes ($($result.Notes.Count)):"
$result.Notes | ForEach-Object { Write-Host "  - $($_.Title)" }
