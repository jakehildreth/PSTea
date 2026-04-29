#Requires -Version 5.1
<#
.SYNOPSIS
    A-04: Capstone — full CRUD task manager with two-column layout.

.DESCRIPTION
    Demonstrates everything in the advanced track:
      - Legacy path (TickMs = 100) for simultaneous char input and timer ticks
      - Two-column layout: task list (left) + detail pane (right)
      - New-TeaList with Done/Undone prefix characters
      - New-TeaTextInput for Title and Description editing
      - Focus state machine: List -> Title -> Description -> Done -> List
      - CRUD: N to add, D x2 to delete, Space to toggle Done
      - PendingDelete double-press guard
      - Fake "saving" feedback: spinner + SaveTicksLeft countdown at 100ms ticks
      - New-TeaProgressBar showing done/total ratio
      - Array immutability via helper function

    Keys (List focus):
      Tab        - enter Title field
      N          - add new task
      D          - press twice to delete current task
      Space      - toggle Done on current task
      Up/Down    - navigate list
      Q          - quit

    Keys (Title / Description focus):
      Tab        - save field and advance to next field
      Escape     - cancel edit, return to List
      Backspace  - delete char left of cursor
      Left/Right - move cursor
      Home/End   - jump to start/end

    Keys (Done focus):
      Space      - toggle Done
      Tab        - save and return to List (triggers fake save)
      Escape     - cancel, return to List

.NOTES
    Run from the repo root:
        pwsh docs/tutorial/advanced/04-capstone-task-manager.ps1
#>

if (-not (Get-Module PSTea)) { Import-Module "$PSScriptRoot/../../../PSTea.psd1" }

# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------

function script:Update-TaskAt {
    param([array]$Tasks, [int]$Index, [PSCustomObject]$NewTask)
    @(0..($Tasks.Count - 1) | ForEach-Object {
        if ($_ -eq $Index) { $NewTask } else { $Tasks[$_] }
    })
}

function script:New-TaskItem {
    param([string]$Title = 'New task', [string]$Description = '')
    [PSCustomObject]@{ Title = $Title; Description = $Description; Done = $false }
}

# ---------------------------------------------------------------------------
# MODEL
# ---------------------------------------------------------------------------

$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Tasks         = @(
                [PSCustomObject]@{ Title = 'Buy milk';      Description = '2% from Costco';   Done = $false }
                [PSCustomObject]@{ Title = 'Read PSTea docs'; Description = 'TEA architecture'; Done = $false }
                [PSCustomObject]@{ Title = 'Write tests';   Description = 'TDD always';        Done = $true  }
            )
            Cursor        = 0
            Focus         = 'List'     # 'List' | 'Title' | 'Description' | 'Done'
            TitleDraft    = ''
            TitleCursor   = 0
            DescDraft     = ''
            DescCursor    = 0
            SpinnerFrame  = 0
            Saving        = $false
            SaveTicksLeft = 0
            PendingDelete = $false
        }
        Cmd = $null
    }
}

# ---------------------------------------------------------------------------
# UPDATE
# ---------------------------------------------------------------------------

$updateFn = {
    param($msg, $model)

    # --- Tick ---
    if ($msg.Type -eq 'Tick') {
        if (-not $model.Saving) {
            return [PSCustomObject]@{ Model = $model; Cmd = $null }
        }
        $left = $model.SaveTicksLeft - 1
        if ($left -le 0) {
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Tasks         = $model.Tasks
                    Cursor        = $model.Cursor
                    Focus         = $model.Focus
                    TitleDraft    = $model.TitleDraft
                    TitleCursor   = $model.TitleCursor
                    DescDraft     = $model.DescDraft
                    DescCursor    = $model.DescCursor
                    SpinnerFrame  = $model.SpinnerFrame
                    Saving        = $false
                    SaveTicksLeft = 0
                    PendingDelete = $model.PendingDelete
                }
                Cmd = $null
            }
        }
        return [PSCustomObject]@{
            Model = [PSCustomObject]@{
                Tasks         = $model.Tasks
                Cursor        = $model.Cursor
                Focus         = $model.Focus
                TitleDraft    = $model.TitleDraft
                TitleCursor   = $model.TitleCursor
                DescDraft     = $model.DescDraft
                DescCursor    = $model.DescCursor
                SpinnerFrame  = $model.SpinnerFrame + 1
                Saving        = $true
                SaveTicksLeft = $left
                PendingDelete = $model.PendingDelete
            }
            Cmd = $null
        }
    }

    # --- Only handle KeyDown from here ---
    if ($msg.Type -ne 'KeyDown') {
        return [PSCustomObject]@{ Model = $model; Cmd = $null }
    }

    # Shortcut: return model with one or more fields changed
    $base = $model  # alias for clarity in switch

    switch ($msg.Key) {

        # --- Navigation (List focus) ---
        'UpArrow' {
            if ($base.Focus -ne 'List') { break }
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Tasks = $base.Tasks; Cursor = [Math]::Max($base.Cursor - 1, 0)
                    Focus = $base.Focus; TitleDraft = $base.TitleDraft; TitleCursor = $base.TitleCursor
                    DescDraft = $base.DescDraft; DescCursor = $base.DescCursor
                    SpinnerFrame = $base.SpinnerFrame; Saving = $base.Saving; SaveTicksLeft = $base.SaveTicksLeft
                    PendingDelete = $false
                }
                Cmd = $null
            }
        }
        'DownArrow' {
            if ($base.Focus -ne 'List') { break }
            $max = $base.Tasks.Count - 1
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Tasks = $base.Tasks; Cursor = [Math]::Min($base.Cursor + 1, $max)
                    Focus = $base.Focus; TitleDraft = $base.TitleDraft; TitleCursor = $base.TitleCursor
                    DescDraft = $base.DescDraft; DescCursor = $base.DescCursor
                    SpinnerFrame = $base.SpinnerFrame; Saving = $base.Saving; SaveTicksLeft = $base.SaveTicksLeft
                    PendingDelete = $false
                }
                Cmd = $null
            }
        }

        # --- Tab: advance focus / save drafts ---
        'Tab' {
            switch ($base.Focus) {
                'List' {
                    if ($base.Tasks.Count -eq 0) { break }
                    $t = $base.Tasks[$base.Cursor]
                    return [PSCustomObject]@{
                        Model = [PSCustomObject]@{
                            Tasks = $base.Tasks; Cursor = $base.Cursor
                            Focus = 'Title'; TitleDraft = $t.Title; TitleCursor = $t.Title.Length
                            DescDraft = $base.DescDraft; DescCursor = $base.DescCursor
                            SpinnerFrame = $base.SpinnerFrame; Saving = $base.Saving; SaveTicksLeft = $base.SaveTicksLeft
                            PendingDelete = $false
                        }
                        Cmd = $null
                    }
                }
                'Title' {
                    if ($base.Tasks.Count -eq 0) { break }
                    $newTask = [PSCustomObject]@{
                        Title       = $base.TitleDraft
                        Description = $base.Tasks[$base.Cursor].Description
                        Done        = $base.Tasks[$base.Cursor].Done
                    }
                    $updated = script:Update-TaskAt -Tasks $base.Tasks -Index $base.Cursor -NewTask $newTask
                    return [PSCustomObject]@{
                        Model = [PSCustomObject]@{
                            Tasks = $updated; Cursor = $base.Cursor
                            Focus = 'Description'; TitleDraft = $base.TitleDraft; TitleCursor = $base.TitleCursor
                            DescDraft = $updated[$base.Cursor].Description; DescCursor = $updated[$base.Cursor].Description.Length
                            SpinnerFrame = $base.SpinnerFrame; Saving = $base.Saving; SaveTicksLeft = $base.SaveTicksLeft
                            PendingDelete = $false
                        }
                        Cmd = $null
                    }
                }
                'Description' {
                    if ($base.Tasks.Count -eq 0) { break }
                    $newTask = [PSCustomObject]@{
                        Title       = $base.Tasks[$base.Cursor].Title
                        Description = $base.DescDraft
                        Done        = $base.Tasks[$base.Cursor].Done
                    }
                    $updated = script:Update-TaskAt -Tasks $base.Tasks -Index $base.Cursor -NewTask $newTask
                    return [PSCustomObject]@{
                        Model = [PSCustomObject]@{
                            Tasks = $updated; Cursor = $base.Cursor
                            Focus = 'Done'; TitleDraft = $base.TitleDraft; TitleCursor = $base.TitleCursor
                            DescDraft = $base.DescDraft; DescCursor = $base.DescCursor
                            SpinnerFrame = $base.SpinnerFrame; Saving = $base.Saving; SaveTicksLeft = $base.SaveTicksLeft
                            PendingDelete = $false
                        }
                        Cmd = $null
                    }
                }
                'Done' {
                    # Commit and trigger fake save
                    return [PSCustomObject]@{
                        Model = [PSCustomObject]@{
                            Tasks = $base.Tasks; Cursor = $base.Cursor
                            Focus = 'List'; TitleDraft = ''; TitleCursor = 0
                            DescDraft = ''; DescCursor = 0
                            SpinnerFrame = 0; Saving = $true; SaveTicksLeft = 10
                            PendingDelete = $false
                        }
                        Cmd = $null
                    }
                }
            }
        }

        # --- Escape: cancel edit ---
        'Escape' {
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Tasks = $base.Tasks; Cursor = $base.Cursor
                    Focus = 'List'; TitleDraft = ''; TitleCursor = 0
                    DescDraft = ''; DescCursor = 0
                    SpinnerFrame = $base.SpinnerFrame; Saving = $base.Saving; SaveTicksLeft = $base.SaveTicksLeft
                    PendingDelete = $false
                }
                Cmd = $null
            }
        }

        # --- N: new task (List only) ---
        'N' {
            if ($base.Focus -ne 'List') { break }
            $newTask = script:New-TaskItem
            $updated = @($base.Tasks) + @($newTask)
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Tasks = $updated; Cursor = $updated.Count - 1
                    Focus = 'List'; TitleDraft = ''; TitleCursor = 0
                    DescDraft = ''; DescCursor = 0
                    SpinnerFrame = $base.SpinnerFrame; Saving = $base.Saving; SaveTicksLeft = $base.SaveTicksLeft
                    PendingDelete = $false
                }
                Cmd = $null
            }
        }

        # --- D: delete with double-press guard (List only) ---
        'D' {
            if ($base.Focus -ne 'List') { break }
            if (-not $base.PendingDelete) {
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Tasks = $base.Tasks; Cursor = $base.Cursor; Focus = $base.Focus
                        TitleDraft = $base.TitleDraft; TitleCursor = $base.TitleCursor
                        DescDraft = $base.DescDraft; DescCursor = $base.DescCursor
                        SpinnerFrame = $base.SpinnerFrame; Saving = $base.Saving; SaveTicksLeft = $base.SaveTicksLeft
                        PendingDelete = $true
                    }
                    Cmd = $null
                }
            }
            if ($base.Tasks.Count -eq 0) {
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Tasks = $base.Tasks; Cursor = 0; Focus = $base.Focus
                        TitleDraft = ''; TitleCursor = 0; DescDraft = ''; DescCursor = 0
                        SpinnerFrame = $base.SpinnerFrame; Saving = $base.Saving; SaveTicksLeft = $base.SaveTicksLeft
                        PendingDelete = $false
                    }
                    Cmd = $null
                }
            }
            $idx     = $base.Cursor
            $updated = @($base.Tasks | Where-Object { $_ -ne $base.Tasks[$idx] })
            $newCur  = [Math]::Max(0, [Math]::Min($base.Cursor, $updated.Count - 1))
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Tasks = $updated; Cursor = $newCur; Focus = 'List'
                    TitleDraft = ''; TitleCursor = 0; DescDraft = ''; DescCursor = 0
                    SpinnerFrame = $base.SpinnerFrame; Saving = $false; SaveTicksLeft = 0
                    PendingDelete = $false
                }
                Cmd = $null
            }
        }

        # --- Space: toggle Done ---
        'Spacebar' {
            if ($base.Focus -eq 'List') {
                if ($base.Tasks.Count -eq 0) { break }
                $t = $base.Tasks[$base.Cursor]
                $newTask = [PSCustomObject]@{ Title = $t.Title; Description = $t.Description; Done = -not $t.Done }
                $updated = script:Update-TaskAt -Tasks $base.Tasks -Index $base.Cursor -NewTask $newTask
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Tasks = $updated; Cursor = $base.Cursor; Focus = 'List'
                        TitleDraft = ''; TitleCursor = 0; DescDraft = ''; DescCursor = 0
                        SpinnerFrame = 0; Saving = $true; SaveTicksLeft = 10
                        PendingDelete = $false
                    }
                    Cmd = $null
                }
            }
            if ($base.Focus -eq 'Done') {
                if ($base.Tasks.Count -eq 0) { break }
                $t = $base.Tasks[$base.Cursor]
                $newTask = [PSCustomObject]@{ Title = $t.Title; Description = $t.Description; Done = -not $t.Done }
                $updated = script:Update-TaskAt -Tasks $base.Tasks -Index $base.Cursor -NewTask $newTask
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Tasks = $updated; Cursor = $base.Cursor; Focus = 'Done'
                        TitleDraft = $base.TitleDraft; TitleCursor = $base.TitleCursor
                        DescDraft = $base.DescDraft; DescCursor = $base.DescCursor
                        SpinnerFrame = $base.SpinnerFrame; Saving = $base.Saving; SaveTicksLeft = $base.SaveTicksLeft
                        PendingDelete = $false
                    }
                    Cmd = $null
                }
            }
        }

        # --- Q: quit (List focus only) ---
        'Q' {
            if ($base.Focus -ne 'List') { break }
            return [PSCustomObject]@{
                Model = $base
                Cmd   = [PSCustomObject]@{ Type = 'Quit' }
            }
        }

        # --- Cursor movement in text fields ---
        'LeftArrow' {
            if ($base.Focus -eq 'Title') {
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Tasks = $base.Tasks; Cursor = $base.Cursor; Focus = $base.Focus
                        TitleDraft = $base.TitleDraft; TitleCursor = [Math]::Max($base.TitleCursor - 1, 0)
                        DescDraft = $base.DescDraft; DescCursor = $base.DescCursor
                        SpinnerFrame = $base.SpinnerFrame; Saving = $base.Saving; SaveTicksLeft = $base.SaveTicksLeft
                        PendingDelete = $base.PendingDelete
                    }
                    Cmd = $null
                }
            }
            if ($base.Focus -eq 'Description') {
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Tasks = $base.Tasks; Cursor = $base.Cursor; Focus = $base.Focus
                        TitleDraft = $base.TitleDraft; TitleCursor = $base.TitleCursor
                        DescDraft = $base.DescDraft; DescCursor = [Math]::Max($base.DescCursor - 1, 0)
                        SpinnerFrame = $base.SpinnerFrame; Saving = $base.Saving; SaveTicksLeft = $base.SaveTicksLeft
                        PendingDelete = $base.PendingDelete
                    }
                    Cmd = $null
                }
            }
        }
        'RightArrow' {
            if ($base.Focus -eq 'Title') {
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Tasks = $base.Tasks; Cursor = $base.Cursor; Focus = $base.Focus
                        TitleDraft = $base.TitleDraft; TitleCursor = [Math]::Min($base.TitleCursor + 1, $base.TitleDraft.Length)
                        DescDraft = $base.DescDraft; DescCursor = $base.DescCursor
                        SpinnerFrame = $base.SpinnerFrame; Saving = $base.Saving; SaveTicksLeft = $base.SaveTicksLeft
                        PendingDelete = $base.PendingDelete
                    }
                    Cmd = $null
                }
            }
            if ($base.Focus -eq 'Description') {
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Tasks = $base.Tasks; Cursor = $base.Cursor; Focus = $base.Focus
                        TitleDraft = $base.TitleDraft; TitleCursor = $base.TitleCursor
                        DescDraft = $base.DescDraft; DescCursor = [Math]::Min($base.DescCursor + 1, $base.DescDraft.Length)
                        SpinnerFrame = $base.SpinnerFrame; Saving = $base.Saving; SaveTicksLeft = $base.SaveTicksLeft
                        PendingDelete = $base.PendingDelete
                    }
                    Cmd = $null
                }
            }
        }
        'Home' {
            if ($base.Focus -eq 'Title') {
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Tasks = $base.Tasks; Cursor = $base.Cursor; Focus = $base.Focus
                        TitleDraft = $base.TitleDraft; TitleCursor = 0
                        DescDraft = $base.DescDraft; DescCursor = $base.DescCursor
                        SpinnerFrame = $base.SpinnerFrame; Saving = $base.Saving; SaveTicksLeft = $base.SaveTicksLeft
                        PendingDelete = $base.PendingDelete
                    }
                    Cmd = $null
                }
            }
            if ($base.Focus -eq 'Description') {
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Tasks = $base.Tasks; Cursor = $base.Cursor; Focus = $base.Focus
                        TitleDraft = $base.TitleDraft; TitleCursor = $base.TitleCursor
                        DescDraft = $base.DescDraft; DescCursor = 0
                        SpinnerFrame = $base.SpinnerFrame; Saving = $base.Saving; SaveTicksLeft = $base.SaveTicksLeft
                        PendingDelete = $base.PendingDelete
                    }
                    Cmd = $null
                }
            }
        }
        'End' {
            if ($base.Focus -eq 'Title') {
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Tasks = $base.Tasks; Cursor = $base.Cursor; Focus = $base.Focus
                        TitleDraft = $base.TitleDraft; TitleCursor = $base.TitleDraft.Length
                        DescDraft = $base.DescDraft; DescCursor = $base.DescCursor
                        SpinnerFrame = $base.SpinnerFrame; Saving = $base.Saving; SaveTicksLeft = $base.SaveTicksLeft
                        PendingDelete = $base.PendingDelete
                    }
                    Cmd = $null
                }
            }
            if ($base.Focus -eq 'Description') {
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Tasks = $base.Tasks; Cursor = $base.Cursor; Focus = $base.Focus
                        TitleDraft = $base.TitleDraft; TitleCursor = $base.TitleCursor
                        DescDraft = $base.DescDraft; DescCursor = $base.DescDraft.Length
                        SpinnerFrame = $base.SpinnerFrame; Saving = $base.Saving; SaveTicksLeft = $base.SaveTicksLeft
                        PendingDelete = $base.PendingDelete
                    }
                    Cmd = $null
                }
            }
        }

        # --- Backspace in text fields ---
        'Backspace' {
            if ($base.Focus -eq 'Title' -and $base.TitleCursor -gt 0) {
                $before = $base.TitleDraft.Substring(0, $base.TitleCursor - 1)
                $after  = $base.TitleDraft.Substring($base.TitleCursor)
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Tasks = $base.Tasks; Cursor = $base.Cursor; Focus = $base.Focus
                        TitleDraft = ($before + $after); TitleCursor = $base.TitleCursor - 1
                        DescDraft = $base.DescDraft; DescCursor = $base.DescCursor
                        SpinnerFrame = $base.SpinnerFrame; Saving = $base.Saving; SaveTicksLeft = $base.SaveTicksLeft
                        PendingDelete = $base.PendingDelete
                    }
                    Cmd = $null
                }
            }
            if ($base.Focus -eq 'Description' -and $base.DescCursor -gt 0) {
                $before = $base.DescDraft.Substring(0, $base.DescCursor - 1)
                $after  = $base.DescDraft.Substring($base.DescCursor)
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Tasks = $base.Tasks; Cursor = $base.Cursor; Focus = $base.Focus
                        TitleDraft = $base.TitleDraft; TitleCursor = $base.TitleCursor
                        DescDraft = ($before + $after); DescCursor = $base.DescCursor - 1
                        SpinnerFrame = $base.SpinnerFrame; Saving = $base.Saving; SaveTicksLeft = $base.SaveTicksLeft
                        PendingDelete = $base.PendingDelete
                    }
                    Cmd = $null
                }
            }
        }

        # --- Printable character input ---
        default {
            if ([char]::IsControl($msg.Char)) {
                return [PSCustomObject]@{ Model = $base; Cmd = $null }
            }

            if ($base.Focus -eq 'Title') {
                $before = $base.TitleDraft.Substring(0, $base.TitleCursor)
                $after  = $base.TitleDraft.Substring($base.TitleCursor)
                $newVal = $before + [string]$msg.Char + $after
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Tasks = $base.Tasks; Cursor = $base.Cursor; Focus = $base.Focus
                        TitleDraft = $newVal; TitleCursor = $base.TitleCursor + 1
                        DescDraft = $base.DescDraft; DescCursor = $base.DescCursor
                        SpinnerFrame = $base.SpinnerFrame; Saving = $base.Saving; SaveTicksLeft = $base.SaveTicksLeft
                        PendingDelete = $false
                    }
                    Cmd = $null
                }
            }

            if ($base.Focus -eq 'Description') {
                $before = $base.DescDraft.Substring(0, $base.DescCursor)
                $after  = $base.DescDraft.Substring($base.DescCursor)
                $newVal = $before + [string]$msg.Char + $after
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{
                        Tasks = $base.Tasks; Cursor = $base.Cursor; Focus = $base.Focus
                        TitleDraft = $base.TitleDraft; TitleCursor = $base.TitleCursor
                        DescDraft = $newVal; DescCursor = $base.DescCursor + 1
                        SpinnerFrame = $base.SpinnerFrame; Saving = $base.Saving; SaveTicksLeft = $base.SaveTicksLeft
                        PendingDelete = $false
                    }
                    Cmd = $null
                }
            }
        }
    }

    # default: no match
    return [PSCustomObject]@{ Model = $base; Cmd = $null }
}

# ---------------------------------------------------------------------------
# VIEW
# ---------------------------------------------------------------------------

$viewFn = {
    param($model)

    $hintStyle     = New-TeaStyle -Foreground 'BrightBlack'
    $headerStyle   = New-TeaStyle -Foreground 'BrightCyan' -Bold
    $selectedStyle = New-TeaStyle -Foreground 'BrightCyan'
    $warningStyle  = New-TeaStyle -Foreground 'BrightRed'

    $tasks  = $model.Tasks
    $count  = if ($null -ne $tasks) { @($tasks).Count } else { 0 }
    $done   = if ($count -gt 0) { ($tasks | Where-Object { $_.Done }).Count } else { 0 }
    $pct    = if ($count -gt 0) { [int]($done / $count * 100) } else { 0 }

    # Build list item strings
    $items = if ($count -gt 0) {
        @($tasks | ForEach-Object { (($_.Done) ? '[x]' : '[ ]') + ' ' + $_.Title })
    } else {
        @('(no tasks)')
    }

    # Left pane
    $deleteHint = if ($model.PendingDelete) {
        New-TeaText -Content '[D] again to confirm delete' -Style $warningStyle
    } else {
        New-TeaText -Content '[D]x2 delete  [N] new' -Style $hintStyle
    }

    $left = New-TeaBox -Style (New-TeaStyle -Width 30 -Border 'Normal' -Padding @(0, 1)) -Children @(
        New-TeaText -Content 'Tasks' -Style $headerStyle
        New-TeaList `
            -Items         $items `
            -SelectedIndex $model.Cursor `
            -MaxVisible    12 `
            -Style         (New-TeaStyle -Foreground 'White') `
            -SelectedStyle $selectedStyle
        New-TeaText -Content ''
        $deleteHint
    )

    # Right pane: detail
    $rightChildren = @(New-TeaText -Content 'Detail' -Style $headerStyle)

    if ($count -gt 0) {
        $task = $tasks[$model.Cursor]

        $titleFocused = ($model.Focus -eq 'Title')
        $descFocused  = ($model.Focus -eq 'Description')
        $doneFocused  = ($model.Focus -eq 'Done')

        $titleDisplay = if ($titleFocused) { $model.TitleDraft } else { $task.Title }
        $descDisplay  = if ($descFocused)  { $model.DescDraft  } else { $task.Description }

        $rightChildren += New-TeaText -Content 'Title:' -Style $hintStyle
        $rightChildren += New-TeaTextInput `
            -Value     $titleDisplay `
            -CursorPos $model.TitleCursor `
            -Focused:  $titleFocused `
            -Placeholder 'Enter title...' `
            -FocusedBoxStyle (New-TeaStyle -Border 'Rounded' -Foreground 'BrightCyan')

        $rightChildren += New-TeaText -Content ''
        $rightChildren += New-TeaText -Content 'Description:' -Style $hintStyle
        $rightChildren += New-TeaTextInput `
            -Value     $descDisplay `
            -CursorPos $model.DescCursor `
            -Focused:  $descFocused `
            -Placeholder 'Enter description...' `
            -FocusedBoxStyle (New-TeaStyle -Border 'Rounded' -Foreground 'BrightCyan')

        $rightChildren += New-TeaText -Content ''
        $doneText = if ($task.Done) { '[x] Done' } else { '[ ] Done' }
        $doneTextStyle = if ($doneFocused) { New-TeaStyle -Foreground 'BrightCyan' } else { $null }
        $rightChildren += New-TeaText -Content $doneText -Style $doneTextStyle

        if ($model.Saving) {
            $rightChildren += New-TeaText -Content ''
            $rightChildren += New-TeaRow -Children @(
                New-TeaSpinner -Frame $model.SpinnerFrame -Variant 'Dots' `
                    -Style (New-TeaStyle -Foreground 'BrightGreen')
                New-TeaText -Content '  Saving...' -Style (New-TeaStyle -Foreground 'BrightGreen')
            )
        }
    } else {
        $rightChildren += New-TeaText -Content 'No tasks. Press [N] to add one.' -Style $hintStyle
    }

    $right = New-TeaBox -Style (New-TeaStyle -Width 44 -Padding @(0, 1)) -Children $rightChildren

    # Progress bar
    $progBar = New-TeaProgressBar -Percent $pct -Width 30 `
        -Style (New-TeaStyle -Foreground 'BrightGreen')

    # Hint bar
    $hintsTop    = '[Tab] edit/advance  [Esc] cancel  [Space] toggle done'
    $hintsBottom = '[Up/Down] navigate  [Q] quit'

    New-TeaBox -Children @(
        New-TeaRow -Children @($left, $right)
        New-TeaText -Content ''
        New-TeaRow -Children @(
            $progBar
            New-TeaText -Content "  $done / $count done  ($pct%)"
        )
        New-TeaText -Content ''
        New-TeaText -Content $hintsTop    -Style $hintStyle
        New-TeaText -Content $hintsBottom -Style $hintStyle
    )
}

# ---------------------------------------------------------------------------
# RUN
# ---------------------------------------------------------------------------

$result = Start-TeaProgram `
    -InitFn   $initFn `
    -UpdateFn $updateFn `
    -ViewFn   $viewFn `
    -TickMs   100

# Final model is returned — could export tasks here:
# $result.Tasks | ConvertTo-Json | Set-Content tasks.json
Write-Host "Exited with $(@($result.Tasks).Count) tasks ($(@($result.Tasks | Where-Object { $_.Done }).Count) done)."
