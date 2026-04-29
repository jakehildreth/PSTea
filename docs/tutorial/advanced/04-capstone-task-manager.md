# A-04 — Capstone: Task Manager

**Track:** Advanced | **Prereqs:** entire curriculum

---

## Objectives

- Combine everything: focus management, CRUD, subscriptions, layout, widgets
- Use `New-TeaList`, `New-TeaTextInput`, `New-TeaProgressBar`, `New-TeaSpinner`
- Implement a two-column layout: list pane (left) + detail pane (right)
- Show fake "saving" feedback using a spinner and a `TickMs` countdown
- Manage an array of task objects immutably

---

## Architecture

### Why the legacy path here?

The task manager uses character input in text fields *and* needs timer ticks for
the saving spinner. The subscription path's `New-TeaCharSub` plus `New-TeaTimerSub`
could work, but there is a subtlety: the `SubscriptionFn` is re-evaluated after
every model update. At 100ms tick rates, this creates many re-evaluations. Using
the **legacy path** (`TickMs = 100` with no `SubscriptionFn`) is simpler:

- Key events arrive as `{ Type = 'KeyDown'; Key = ...; Char = ... }`
- Timer ticks arrive as `{ Type = 'Tick' }`
- One `switch` in `UpdateFn` dispatches both

Because the legacy path does not use subscriptions, key matching is done manually:

```powershell
$updateFn = {
    param($msg, $model)
    if ($msg.Type -eq 'Tick') {
        # handle timer
        ...
    }
    if ($msg.Type -eq 'KeyDown') {
        switch ($msg.Key) {
            'Tab'    { ... }
            'Q'      { ... }
            default  {
                # printable characters: check focus and append
                if (-not [char]::IsControl($msg.Char)) {
                    ...
                }
            }
        }
    }
    return [PSCustomObject]@{ Model = $model; Cmd = $null }
}
```

### Focus state machine

```
        Tab                     Tab
  List ────> Title ────> Description ────> Done ──(Tab)──> List
    ^                                                         |
    └──────────────────── Escape ─────────────────────────────┘
```

When entering `Title` or `Description`, copy the current task's value into a
draft field. When Tab or Enter saves the field, write the draft back to the task.
Escape cancels the edit.

### Model shape

```powershell
[PSCustomObject]@{
    Tasks         = @(
        [PSCustomObject]@{ Title='Buy milk'; Description='2% from Costco'; Done=$false }
        [PSCustomObject]@{ Title='Read docs'; Description='TEA architecture'; Done=$false }
    )
    Cursor        = 0      # selected task index
    Focus         = 'List' # 'List' | 'Title' | 'Description' | 'Done'
    TitleDraft    = ''
    TitleCursor   = 0      # text cursor position in TitleDraft
    DescDraft     = ''
    DescCursor    = 0
    SpinnerFrame  = 0
    Saving        = $false
    SaveTicksLeft = 0
    PendingDelete = $false
}
```

`PendingDelete` is the double-press guard: first D sets it to `$true`, a second D
actually deletes. Any other key clears it.

---

## Step-by-Step Build

### Step 1 — Scaffold

```powershell
if (-not (Get-Module PSTea)) { Import-Module "$PSScriptRoot/../../../PSTea.psd1" }

$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Tasks         = @(
                [PSCustomObject]@{ Title='Buy milk'; Description=''; Done=$false }
            )
            Cursor        = 0
            Focus         = 'List'
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

$updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
$viewFn   = { param($model) New-TeaText -Content 'Task Manager' }

Start-TeaProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -TickMs 100
```

Run it. You see `Task Manager`. Quit with Ctrl+C for now.

---

### Step 2 — View skeleton

```powershell
$viewFn = {
    param($model)

    $tasks = $model.Tasks
    $done  = ($tasks | Where-Object { $_.Done }).Count
    $total = $tasks.Count
    $pct   = if ($total -gt 0) { [int]($done / $total * 100) } else { 0 }

    # Left pane: list
    $items  = $tasks | ForEach-Object { ($_.Done ? '[x]' : '[ ]') + ' ' + $_.Title }
    $left   = New-TeaBox -Style (New-TeaStyle -Width 28 -Border 'Normal' -Padding @(0, 1)) -Children @(
        New-TeaText -Content 'Tasks' -Style (New-TeaStyle -Bold)
        New-TeaList -Items $items -SelectedIndex $model.Cursor -MaxVisible 10 `
            -Style         (New-TeaStyle -Foreground 'White') `
            -SelectedStyle (New-TeaStyle -Foreground 'BrightCyan')
    )

    # Right pane: detail
    $task = if ($tasks.Count -gt 0) { $tasks[$model.Cursor] } else { $null }
    $rightChildren = @(
        New-TeaText -Content 'Detail' -Style (New-TeaStyle -Bold)
    )
    if ($task) {
        $rightChildren += New-TeaTextInput `
            -Value     $model.TitleDraft `
            -CursorPos $model.TitleCursor `
            -Focused:  ($model.Focus -eq 'Title') `
            -Placeholder 'Title...'
        $rightChildren += New-TeaTextInput `
            -Value     $model.DescDraft `
            -CursorPos $model.DescCursor `
            -Focused:  ($model.Focus -eq 'Description') `
            -Placeholder 'Description...'
        $rightChildren += New-TeaText -Content (($task.Done) ? '[x] Done' : '[ ] Done')
        if ($model.Saving) {
            $rightChildren += New-TeaRow -Children @(
                New-TeaSpinner -Frame $model.SpinnerFrame -Variant 'Dots'
                New-TeaText -Content '  Saving...'
            )
        }
    }
    $right = New-TeaBox -Style (New-TeaStyle -Width 46 -Padding @(0, 1)) -Children $rightChildren

    New-TeaBox -Children @(
        New-TeaRow -Children @($left, $right)
        New-TeaText -Content ''
        New-TeaProgressBar -Percent $pct -Width 30
        New-TeaText -Content "$done / $total done"
        New-TeaText -Content '[Tab] focus  [N] new  [D]x2 delete  [Space] toggle done  [Q] quit' `
            -Style (New-TeaStyle -Foreground 'BrightBlack')
    )
}
```

---

### Step 3 — Tick handler + saving spinner

```powershell
# Inside $updateFn, first block:
if ($msg.Type -eq 'Tick') {
    if ($model.Saving) {
        $left = $model.SaveTicksLeft - 1
        if ($left -le 0) {
            return [PSCustomObject]@{
                Model = ... with Saving = $false; SaveTicksLeft = 0 ...
                Cmd   = $null
            }
        }
        return [PSCustomObject]@{
            Model = ... with SpinnerFrame = $model.SpinnerFrame + 1; SaveTicksLeft = $left ...
            Cmd   = $null
        }
    }
    return [PSCustomObject]@{ Model = $model; Cmd = $null }
}
```

`SaveTicksLeft = 10` means 10 x 100ms = 1 second of spinner before "save" completes.

---

### Step 4 — Tab key / focus transitions

```powershell
'Tab' {
    switch ($model.Focus) {
        'List' {
            # Load draft from current task
            $t = $model.Tasks[$model.Cursor]
            return ... Focus = 'Title'; TitleDraft = $t.Title; TitleCursor = $t.Title.Length ...
        }
        'Title' {
            # Save title draft back to task
            $updated = # ... update task at Cursor with TitleDraft ...
            return ... Tasks = $updated; Focus = 'Description'; DescDraft = $updated[$model.Cursor].Description ...
        }
        'Description' {
            $updated = # ... update task at Cursor with DescDraft ...
            return ... Tasks = $updated; Focus = 'Done' ...
        }
        'Done' {
            # Trigger the fake save
            return ... Focus = 'List'; Saving = $true; SaveTicksLeft = 10 ...
        }
    }
}
```

---

### Step 5 — Character input (Title and Description)

```powershell
default {
    if ([char]::IsControl($msg.Char)) {
        return [PSCustomObject]@{ Model = $model; Cmd = $null }
    }
    if ($model.Focus -eq 'Title') {
        $before = $model.TitleDraft.Substring(0, $model.TitleCursor)
        $after  = $model.TitleDraft.Substring($model.TitleCursor)
        $newVal = $before + $msg.Char + $after
        return ... TitleDraft = $newVal; TitleCursor = $model.TitleCursor + 1 ...
    }
    if ($model.Focus -eq 'Description') {
        $before = $model.DescDraft.Substring(0, $model.DescCursor)
        $after  = $model.DescDraft.Substring($model.DescCursor)
        $newVal = $before + $msg.Char + $after
        return ... DescDraft = $newVal; DescCursor = $model.DescCursor + 1 ...
    }
    return [PSCustomObject]@{ Model = $model; Cmd = $null }
}
```

---

### Step 6 — CRUD

**New task (N key, List focus only):**

```powershell
'N' {
    if ($model.Focus -ne 'List') { return ... $model ... }
    $newTask = [PSCustomObject]@{ Title = 'New task'; Description = ''; Done = $false }
    $updated = @($model.Tasks) + @($newTask)
    return ... Tasks = $updated; Cursor = $updated.Count - 1 ...
}
```

**Delete with guard (D key):**

```powershell
'D' {
    if ($model.Focus -ne 'List') { return ... $model ... }
    if (-not $model.PendingDelete) {
        return ... PendingDelete = $true ...
    }
    # Second D: delete
    $updated = @($model.Tasks | Where-Object { $_ -ne $model.Tasks[$model.Cursor] })
    $newCursor = [Math]::Min($model.Cursor, $updated.Count - 1)
    if ($newCursor -lt 0) { $newCursor = 0 }
    return ... Tasks = $updated; Cursor = $newCursor; PendingDelete = $false ...
}
```

**Toggle Done (Space key):**

```powershell
'Spacebar' {
    if ($model.Focus -ne 'List') { return ... $model ... }
    $updated = 0..($model.Tasks.Count - 1) | ForEach-Object {
        if ($_ -eq $model.Cursor) {
            [PSCustomObject]@{
                Title       = $model.Tasks[$_].Title
                Description = $model.Tasks[$_].Description
                Done        = -not $model.Tasks[$_].Done
            }
        } else { $model.Tasks[$_] }
    }
    return ... Tasks = @($updated); Saving = $true; SaveTicksLeft = 10 ...
}
```

---

## Architecture Walkthrough

### Focus field encodes the whole editing state

There is no separate `Editing` boolean. If `Focus -ne 'List'`, the app is editing.
The View renders `New-TeaTextInput -Focused` only when `Focus -eq 'Title'` etc.

### Draft fields decouple editing from the live task list

Title and Description edits live in `TitleDraft` / `DescDraft` until Tab commits them.
Escape can simply clear the draft and return `Focus = 'List'` without touching `Tasks`.

### Array immutability pattern (review)

```powershell
function script:Update-TaskAt {
    param($tasks, $index, $newTask)
    @(0..($tasks.Count - 1) | ForEach-Object {
        if ($_ -eq $index) { $newTask } else { $tasks[$_] }
    })
}
```

### TickMs vs SubscriptionFn — choosing the right tool

| Scenario | Use |
|----------|-----|
| Char input + timer in same app | `TickMs` (legacy path) |
| Only key subs + timer | `SubscriptionFn` (subscription path) |
| Two timers at different rates | Either; `SubscriptionFn` is cleaner |
| No timer needed | `SubscriptionFn` is cleaner for key-only apps |

---

## Exercises

1. **Escape to cancel.** Pressing Escape while `Focus` is `Title` or `Description`
   should restore `Focus = 'List'` and discard the draft.

2. **Backspace.** In the `Title`/`Description` handlers for `'Backspace'`, trim one
   character from the draft at `CursorPos - 1`.

3. **Prioritized task display.** Add a `Priority` field (`'Low'`/`'Medium'`/`'High'`)
   to each task. In the list, colour the items: High = BrightRed, Medium = Yellow, Low = White.
   Use P/L keys to cycle priority when `Focus = 'List'`.

4. **Export.** After Quit, the final model is returned by `Start-TeaProgram`. In the
   caller script, access `$result.Tasks | ConvertTo-Json | Set-Content tasks.json`.
