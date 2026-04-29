# I-05 — Capstone: Note Taker

**Track:** Intermediate | **Prereqs:** I-01 through I-04

This capstone combines everything from the Intermediate track: lists, text input,
focus cycling, form fields, and CRUD operations on an in-memory data store.

The companion script [`05-capstone-note-taker.ps1`](05-capstone-note-taker.ps1)
is the reference implementation. Read this alongside it.

---

## What the App Does

A two-panel note manager. Left panel: scrollable list of note titles. Right panel:
editable note body for the selected note.

| Key | Action |
|-----|--------|
| Up / Down arrows | Navigate the note list (Browse mode) |
| N | Create a new note |
| D | Delete the selected note (double-press guard) |
| E | Edit the selected note's title |
| Enter (in title edit) | Confirm new title |
| Escape (in title edit) | Cancel edit |
| Tab | Cycle focus: List → Body → List |
| Printable chars (body focused) | Append to note body |
| Backspace (body focused) | Delete last character of body |
| Q | Quit — returns the notes array |

---

## Model Shape

```powershell
[PSCustomObject]@{
    Notes         = @(
        [PSCustomObject]@{ Title = 'Welcome'; Body = 'Start typing...' }
    )
    Cursor        = 0          # selected note index in the list
    Focus         = 'List'     # 'List' | 'Body' | 'EditTitle'
    TitleDraft    = ''         # in-progress title being edited
    PendingDelete = $false     # double-press D guard
}
```

Three focus states:
- `'List'` — arrow keys navigate, N/D/E available, Tab moves to Body
- `'Body'` — character keys edit the selected note's body, Tab moves to List
- `'EditTitle'` — typing edits `TitleDraft`, Enter confirms, Escape cancels

---

## Section A — Step-by-Step Build

### Step 1 — Browse mode: list navigation

Start with only `'List'` focus and Up/Down navigation:

```powershell
$subscriptionFn = {
    param($model)
    @(
        New-TeaKeySub -Key 'UpArrow'   -Handler { 'MoveUp' }
        New-TeaKeySub -Key 'DownArrow' -Handler { 'MoveDown' }
        New-TeaKeySub -Key 'Tab'       -Handler { 'Tab' }
        New-TeaKeySub -Key 'Q'         -Handler { 'Quit' }
    )
}
```

In Update, clamped navigation (notes have a defined start/end):

```powershell
'MoveUp' {
    $prev = [Math]::Max(0, $model.Cursor - 1)
    return [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Notes         = $model.Notes
            Cursor        = $prev
            Focus         = $model.Focus
            TitleDraft    = $model.TitleDraft
            PendingDelete = $false   # cancel pending delete when moving
        }
        Cmd = $null
    }
}
```

In View, split the screen with `New-TeaRow`:

```powershell
$viewFn = {
    param($model)
    $selectedNote = $model.Notes[$model.Cursor]
    $titles = $model.Notes | ForEach-Object { $_.Title }

    New-TeaRow -Children @(
        # Left: list of titles
        New-TeaBox -Style (New-TeaStyle -Border 'Rounded' -Width 24 -Padding @(0, 1)) -Children @(
            New-TeaList -Items $titles -SelectedIndex $model.Cursor -MaxVisible 16
        )
        # Right: note body
        New-TeaBox -Style (New-TeaStyle -Border 'Rounded' -Width 40 -MarginLeft 2 -Padding @(0, 1)) -Children @(
            New-TeaText -Content $selectedNote.Title -Style (New-TeaStyle -Foreground 'BrightCyan' -Bold)
            New-TeaText -Content ''
            New-TeaText -Content $selectedNote.Body
        )
    )
}
```

Run it. The list shows one note; Up/Down does nothing (one item). Tab does nothing
yet. Q quits.

### Step 2 — Adding new notes

Add `New-TeaKeySub -Key 'N' -Handler { 'NewNote' }` to the subscription list.

In Update:

```powershell
'NewNote' {
    # Construct a new notes array — do not mutate $model.Notes in place.
    $newNote  = [PSCustomObject]@{ Title = "Note $($model.Notes.Count + 1)"; Body = '' }
    $newNotes = @($model.Notes) + @($newNote)
    return [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Notes         = $newNotes
            Cursor        = $newNotes.Count - 1   # jump to the new note
            Focus         = 'EditTitle'            # immediately start renaming it
            TitleDraft    = $newNote.Title
            PendingDelete = $false
        }
        Cmd = $null
    }
}
```

`@($model.Notes) + @($newNote)` creates a new array. Never use `.Add()` on an array
in PSTea Update — use this concatenation pattern.

### Step 3 — Title editing (`EditTitle` focus)

Add title-editing branches. These only fire in `'EditTitle'` mode.

In `SubscriptionFn`, conditionally add the char sub:

```powershell
if ($model.Focus -eq 'EditTitle') {
    $subs += New-TeaCharSub -Handler { param($e) "Char:$([string]$e.Char)" }
    $subs += New-TeaKeySub -Key 'Enter'     -Handler { 'ConfirmTitle' }
    $subs += New-TeaKeySub -Key 'Escape'    -Handler { 'CancelTitle' }
    $subs += New-TeaKeySub -Key 'Backspace' -Handler { 'TitleBackspace' }
}
```

In Update, `ConfirmTitle` replaces the selected note's title with `TitleDraft`:

```powershell
'ConfirmTitle' {
    $title = if ($model.TitleDraft.Trim() -ne '') { $model.TitleDraft } else {
        $model.Notes[$model.Cursor].Title
    }
    $updatedNotes = 0..($model.Notes.Count - 1) | ForEach-Object {
        if ($_ -eq $model.Cursor) {
            [PSCustomObject]@{ Title = $title; Body = $model.Notes[$_].Body }
        } else {
            $model.Notes[$_]
        }
    }
    return [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Notes         = @($updatedNotes)
            Cursor        = $model.Cursor
            Focus         = 'List'
            TitleDraft    = ''
            PendingDelete = $false
        }
        Cmd = $null
    }
}
```

`0..($model.Notes.Count - 1) | ForEach-Object { ... }` is the idiomatic way to
map over an indexed array in PowerShell without mutating.

In View, show the draft with a cursor when in `'EditTitle'` mode:

```powershell
$titleDisplay = if ($model.Focus -eq 'EditTitle') {
    "$($model.TitleDraft)_"
} else {
    $selectedNote.Title
}

New-TeaText -Content $titleDisplay -Style (New-TeaStyle -Foreground 'BrightCyan' -Bold)
```

### Step 4 — Delete with double-press guard

```powershell
# In SubscriptionFn (always available in List mode)
if ($model.Focus -eq 'List') {
    $subs += New-TeaKeySub -Key 'D' -Handler { 'Delete' }
}
```

In Update:

```powershell
'Delete' {
    if (-not $model.PendingDelete) {
        # First press: arm the guard
        return [PSCustomObject]@{
            Model = [PSCustomObject]@{
                Notes         = $model.Notes
                Cursor        = $model.Cursor
                Focus         = $model.Focus
                TitleDraft    = $model.TitleDraft
                PendingDelete = $true
            }
            Cmd = $null
        }
    }
    # Second press: execute the delete
    if ($model.Notes.Count -le 1) {
        # Do not delete the last note
        return [PSCustomObject]@{
            Model = [PSCustomObject]@{
                Notes         = $model.Notes
                Cursor        = 0
                Focus         = $model.Focus
                TitleDraft    = ''
                PendingDelete = $false
            }
            Cmd = $null
        }
    }
    $newNotes = @($model.Notes | Where-Object { $_ -ne $model.Notes[$model.Cursor] })
    $newCursor = [Math]::Min($model.Cursor, $newNotes.Count - 1)
    return [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Notes         = $newNotes
            Cursor        = $newCursor
            Focus         = 'List'
            TitleDraft    = ''
            PendingDelete = $false
        }
        Cmd = $null
    }
}
```

In View, show `'[D] delete (press again to confirm)'` in `BrightYellow` when
`PendingDelete` is `$true`.

### Step 5 — Body editing (`Body` focus)

Tab from List → Body. In Body, the char sub is active; text appends to the note body.

In `SubscriptionFn`:

```powershell
if ($model.Focus -eq 'Body') {
    $subs += New-TeaCharSub -Handler { param($e) "Char:$([string]$e.Char)" }
    $subs += New-TeaKeySub -Key 'Backspace' -Handler { 'BodyBackspace' }
}
```

Update `'Char:*'` in body mode (needs focus check — or just make separate subs):

```powershell
# Only fires when body focus (because char sub is conditional)
'Char:*' {
    $ch = $msg.Substring(5)
    $currentBody = $model.Notes[$model.Cursor].Body
    $newBody     = $currentBody + $ch
    $updatedNotes = 0..($model.Notes.Count - 1) | ForEach-Object {
        if ($_ -eq $model.Cursor) {
            [PSCustomObject]@{ Title = $model.Notes[$_].Title; Body = $newBody }
        } else {
            $model.Notes[$_]
        }
    }
    return [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Notes         = @($updatedNotes)
            Cursor        = $model.Cursor
            Focus         = $model.Focus
            TitleDraft    = $model.TitleDraft
            PendingDelete = $false
        }
        Cmd = $null
    }
}
```

---

## Section B — Architecture Walkthrough

### Three focus states as a mini state machine

```
         Tab                Tab
 List ─────────▶ Body ─────────▶ List
   │                              ▲
   │ E / N                        │
   ▼                              │
 EditTitle ───── Enter/Escape ────┘
```

- `List` is the "home" state. Navigation, N, D, E all only fire from here.
- `Body` captures all printable input. Tab returns to List.
- `EditTitle` captures all printable input for the title draft. Enter/Escape return to List.

### Array immutability — the map pattern

Never mutate `$model.Notes` directly. The idiomatic way to update one note in the array:

```powershell
$updatedNotes = 0..($model.Notes.Count - 1) | ForEach-Object {
    if ($_ -eq $model.Cursor) {
        [PSCustomObject]@{ Title = $newTitle; Body = $model.Notes[$_].Body }
    } else {
        $model.Notes[$_]
    }
}
return @($updatedNotes)
```

This produces a new array; the original `$model.Notes` is untouched.

### Returning data to the caller

```powershell
$result = Start-TeaProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -SubscriptionFn $subscriptionFn
# $result.Notes is the final array of note objects
$result.Notes | ForEach-Object { Write-Host "$($_.Title): $($_.Body)" }
```

---

## What's Next

You have completed the **Intermediate track**. You can now:
- Manage structured data (arrays of objects) in the model
- Implement CRUD operations immutably
- Use focus states and conditional subscriptions
- Build multi-panel two-column layouts

Continue to the **Advanced track**, starting with:

**[A-01 — Components](../advanced/01-components.md):** encapsulate reusable,
self-contained UI elements with their own Init/Update/View.
