# B-05 — Capstone: Nameable Counter

**Track:** Beginner | **Prereqs:** B-01 through B-04

This capstone brings together everything from the Beginner track:
model design, interactive key handling, conditional rendering, and full styling.

The companion script [`05-capstone-nameable-counter.ps1`](05-capstone-nameable-counter.ps1)
is the reference implementation. Read this file alongside it.

---

## What the App Does

A styled counter in a Rounded-bordered box. The counter has a **name** that the user
can change at runtime.

| Key | Action |
|-----|--------|
| Up arrow | Increment count |
| Down arrow | Decrement count |
| E | Enter rename mode (start typing a new name) |
| Backspace | (in rename mode) delete last character |
| Enter | (in rename mode) confirm new name |
| Escape | (in rename mode) cancel — discard draft, keep old name |
| Q | Quit — **only works when not in rename mode** |

The app returns the final model (including `Name` and `Count`) after exit.

---

## Section A — Step-by-Step Build

Follow along in an empty `.ps1` file. Each step adds one piece.

### Step 1 — Import and stub

```powershell
if (-not (Get-Module PSTea)) { Import-Module "$PSScriptRoot/../../../PSTea.psd1" }

$initFn   = { [PSCustomObject]@{ Model = [PSCustomObject]@{ Count = 0 }; Cmd = $null } }
$updateFn = { param($msg, $model) [PSCustomObject]@{ Model = $model; Cmd = $null } }
$viewFn   = { param($model) New-TeaText -Content "Count: $($model.Count)" }

Start-TeaProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn
```

Run it. You should see `Count: 0`. Nothing is interactive yet (Q does not work). Kill
it with Ctrl+C. We will fix that next.

### Step 2 — Define the full model

Replace `$initFn` with the complete model shape:

```powershell
$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Name      = 'My Counter'   # display name
            Count     = 0              # current value
            Editing   = $false         # whether rename mode is active
            NameDraft = ''             # in-progress name being typed
        }
        Cmd = $null
    }
}
```

Four fields. Explain each:
- `Name` — shown in the header. Updated when the user confirms a rename.
- `Count` — the integer being inc/dec'd.
- `Editing` — acts as a **mode flag**. When `$true`, key input goes to renaming, not
  counting. This is the core pattern for mode-switching in PSTea.
- `NameDraft` — accumulates typed characters during rename mode. Discarded on Escape,
  committed to `Name` on Enter.

### Step 3 — Update: counting keys

Replace `$updateFn` with the counting branches. We will add the editing branches next.

```powershell
$updateFn = {
    param($msg, $model)

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
        'Q' {
            return [PSCustomObject]@{ Model = $model; Cmd = [PSCustomObject]@{ Type = 'Quit' } }
        }
        default {
            return [PSCustomObject]@{ Model = $model; Cmd = $null }
        }
    }
}
```

Run it. Up and Down arrows should change the count. Q quits.

Notice that every branch that produces a new model explicitly carries all four fields
forward. When `Count` changes, `Name`, `Editing`, and `NameDraft` are still present.

### Step 4 — Update: the mode guard

We need two separate behaviors depending on `model.Editing`. The cleanest approach:
check the mode at the top of Update and branch before the `switch`.

```powershell
$updateFn = {
    param($msg, $model)

    # --- Editing mode: character input goes to NameDraft ---
    if ($model.Editing) {
        switch ($msg.Key) {
            'Enter' {
                $confirmedName = if ($model.NameDraft -ne '') { $model.NameDraft } else { $model.Name }
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
                $draft = if ($model.NameDraft.Length -gt 0) {
                    $model.NameDraft.Substring(0, $model.NameDraft.Length - 1)
                } else { '' }
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
                # Single printable character — append to draft
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
                return [PSCustomObject]@{ Model = $model; Cmd = $null }
            }
        }
    }

    # --- Normal mode ---
    switch ($msg.Key) {
        'UpArrow'   { ... }   # same as before
        'DownArrow' { ... }
        'E' {
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Name      = $model.Name
                    Count     = $model.Count
                    Editing   = $true
                    NameDraft = ''          # start fresh — user types the new name
                }
                Cmd = $null
            }
        }
        'Q' {
            # NOTE: Q only works in normal mode. In editing mode, 'Q' is a printable
            # character and would append to NameDraft instead.
            return [PSCustomObject]@{ Model = $model; Cmd = [PSCustomObject]@{ Type = 'Quit' } }
        }
        default { return [PSCustomObject]@{ Model = $model; Cmd = $null } }
    }
}
```

Key insight: the `if ($model.Editing)` block at the top of Update is a **mode guard**.
It intercepts all keys and processes them differently when the app is in editing mode.
This is the standard PSTea pattern for mode-based apps (search boxes, rename dialogs, etc.).

### Step 5 — View: conditional rendering

```powershell
$viewFn = {
    param($model)

    $nameStyle  = New-TeaStyle -Foreground 'BrightCyan'  -Bold
    $countStyle = New-TeaStyle -Foreground 'BrightWhite' -Bold
    $editStyle  = New-TeaStyle -Foreground 'BrightYellow'
    $hintStyle  = New-TeaStyle -Foreground 'BrightBlack'
    $boxStyle   = New-TeaStyle -Border 'Rounded' -Padding @(0, 2) -Width 36

    if ($model.Editing) {
        # Editing mode: show the draft with a cursor underscore
        $prompt = "New name: $($model.NameDraft)_"
        New-TeaBox -Style $boxStyle -Children @(
            New-TeaText -Content $model.Name            -Style $nameStyle
            New-TeaText -Content "  $($model.Count)"   -Style $countStyle
            New-TeaText -Content ''
            New-TeaText -Content $prompt                -Style $editStyle
            New-TeaText -Content '[Enter] confirm  [Esc] cancel  [Backspace] delete' -Style $hintStyle
        )
    } else {
        # Normal mode
        New-TeaBox -Style $boxStyle -Children @(
            New-TeaText -Content $model.Name            -Style $nameStyle
            New-TeaText -Content "  $($model.Count)"   -Style $countStyle
            New-TeaText -Content ''
            New-TeaText -Content '[Up] inc  [Down] dec  [E] rename  [Q] quit' -Style $hintStyle
        )
    }
}
```

The view branch on `$model.Editing` shows entirely different content. This is
conditional rendering — the same model field that drives Update's mode guard also
drives View's display.

---

## Section B — Architecture Walkthrough

### Model as state machine

The `Editing` field in the model is a **two-state mode flag**. It turns the model into
a simple state machine:

```
   Normal ──E──▶ Editing
   Editing ──Enter──▶ Normal (with Name updated)
   Editing ──Escape──▶ Normal (Name unchanged)
```

In normal mode: Up/Down change Count, E starts editing, Q quits.  
In editing mode: printable characters append to NameDraft, Backspace removes the last
character, Enter commits, Escape cancels.

### The Q guard

The most common mistake in mode-based apps is handling Q globally:

```powershell
# Wrong: Q in normal mode quits, but Q in editing mode should type 'q'
switch ($msg.Key) {
    'Q' { return [PSCustomObject]@{ Model = $model; Cmd = [PSCustomObject]@{ Type = 'Quit' } } }
    ...
}
```

The correct pattern: the `if ($model.Editing)` block at the top of Update intercepts
all keys in editing mode. The `'Q'` branch in the normal-mode switch is only reached
when `$model.Editing` is `$false`.

### Using `$msg.Char` for text input

In the editing mode `default` branch:

```powershell
if (-not [char]::IsControl($msg.Char) -and $msg.Char -ne [char]0) {
    # append $msg.Char to NameDraft
}
```

`$msg.Char` is the actual typed character (preserving case and symbols).
`$msg.Key` is the ConsoleKey enum name — always uppercase for letters, not useful
for text insertion. Use `$msg.Char` for text input; use `$msg.Key` for control keys.

---

## Section C — Numbered Steps with Full Snippets

**1. Import the module**
```powershell
if (-not (Get-Module PSTea)) { Import-Module "$PSScriptRoot/../../../PSTea.psd1" }
```

**2. Define Init**
```powershell
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
```

**3. Define Update** — see the companion `.ps1` for the full implementation.
The complete Update is ~70 lines. Key structure:
```
if ($model.Editing) {
    switch ($msg.Key) { 'Enter' | 'Escape' | 'Backspace' | default (char append) }
}
switch ($msg.Key) { 'UpArrow' | 'DownArrow' | 'E' | 'Q' | default }
```

**4. Define View**
```powershell
$viewFn = {
    param($model)
    $boxStyle = New-TeaStyle -Border 'Rounded' -Padding @(0, 2) -Width 36
    if ($model.Editing) {
        New-TeaBox -Style $boxStyle -Children @(
            New-TeaText -Content $model.Name          -Style (New-TeaStyle -Foreground 'BrightCyan' -Bold)
            New-TeaText -Content "  $($model.Count)"  -Style (New-TeaStyle -Foreground 'BrightWhite' -Bold)
            New-TeaText -Content ''
            New-TeaText -Content "New name: $($model.NameDraft)_" -Style (New-TeaStyle -Foreground 'BrightYellow')
            New-TeaText -Content '[Enter] confirm  [Esc] cancel'  -Style (New-TeaStyle -Foreground 'BrightBlack')
        )
    } else {
        New-TeaBox -Style $boxStyle -Children @(
            New-TeaText -Content $model.Name          -Style (New-TeaStyle -Foreground 'BrightCyan' -Bold)
            New-TeaText -Content "  $($model.Count)"  -Style (New-TeaStyle -Foreground 'BrightWhite' -Bold)
            New-TeaText -Content ''
            New-TeaText -Content '[Up] inc  [Down] dec  [E] rename  [Q] quit' -Style (New-TeaStyle -Foreground 'BrightBlack')
        )
    }
}
```

**5. Run it**
```powershell
$finalModel = Start-TeaProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn
Write-Host "Final: $($finalModel.Name) = $($finalModel.Count)"
```

---

## What's Next

You have completed the **Beginner track**. You can now:
- Build interactive PSTea apps with stateful models
- Use mode flags to give the same key different meanings depending on context
- Style with colors, borders, padding
- Return data from a TUI to the calling script

Continue to the **Intermediate track**, starting with:

**[I-01 — Subscriptions](../intermediate/01-subscriptions.md):** replace the raw
`$msg.Key` switch with a declarative subscription system — and add a live countdown
timer with pause/resume.
