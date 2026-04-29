# B-03 — Increment/Decrement

## Objectives

By the end of this lesson you will be able to:

- Describe what a **message** (`$msg`) is and where it comes from
- Write an Update function using the `switch ($msg.Key)` pattern
- Explain why you construct a new model instead of mutating the existing one
- Always include a `default` branch in Update
- Reflect changing model state in the view via string interpolation

---

## Prerequisites

> **Prior lesson:** [B-02 — Hello, PSTea](02-hello-pstea.md)
>
> **Concepts needed:** The MVU data-flow cycle from B-01. `New-TeaText`, `New-TeaBox`,
> and `Start-TeaProgram` from B-02.

---

## Concept

### What is a message?

Every time the user presses a key, the terminal driver creates a message and places it
on the **input queue**. PSTea dequeues it and calls your `UpdateFn` with it as `$msg`.

In the **legacy key path** (when you do not pass a `SubscriptionFn` to
`Start-TeaProgram`), `$msg` is a `PSCustomObject`:

```
$msg.Type      = 'KeyDown'
$msg.Key       = 'UpArrow'   # string — the ConsoleKey enum name
$msg.Char      = [char]0     # the typed character (blank for control keys)
$msg.Modifiers = 0           # Shift / Ctrl / Alt flags
```

The `.Key` property is the string name of the .NET `ConsoleKey` enum value. For
letter keys this is the uppercase letter. For special keys it is the full name.

Common key strings:

| Key | `$msg.Key` |
|-----|-----------|
| Up arrow | `'UpArrow'` |
| Down arrow | `'DownArrow'` |
| Left arrow | `'LeftArrow'` |
| Right arrow | `'RightArrow'` |
| Enter | `'Enter'` |
| Backspace | `'Backspace'` |
| Escape | `'Escape'` |
| Space | `'Spacebar'` |
| Q key | `'Q'` |
| Letter A | `'A'` |
| Digit 3 | `'D3'` |

### The `switch` skeleton

The standard Update pattern is a `switch` on `$msg.Key`:

```powershell
$updateFn = {
    param($msg, $model)
    switch ($msg.Key) {
        'UpArrow'   { [PSCustomObject]@{ Model = ...; Cmd = $null } }
        'DownArrow' { [PSCustomObject]@{ Model = ...; Cmd = $null } }
        'Q'         { [PSCustomObject]@{ Model = $model; Cmd = [PSCustomObject]@{ Type = 'Quit' } } }
        default     { [PSCustomObject]@{ Model = $model; Cmd = $null } }
    }
}
```

The `default` branch is **required**. Without it, unhandled keys return `$null` from
Update, which causes the event loop to error.

### Immutability: why construct a new object?

Recall from B-01: PSTea deep-copies the model before passing it to Update. So
technically you _could_ mutate `$model` — you're modifying a copy.

But the idiomatic pattern is to construct a new `PSCustomObject`:

```powershell
# Wrong — mutation in place
$model.Count++
[PSCustomObject]@{ Model = $model; Cmd = $null }

# Right — construct a new model
[PSCustomObject]@{
    Model = [PSCustomObject]@{ Count = $model.Count + 1 }
    Cmd   = $null
}
```

Why? Constructing a new object:
- Forces you to name every field you carry forward — stale state can't sneak through
- Makes the intent of each branch explicit
- Keeps Update stateless in spirit even if not strictly required

### Reflecting state in View

Use PS double-quoted string interpolation inside `New-TeaText -Content`:

```powershell
$viewFn = {
    param($model)
    New-TeaText -Content "Count: $($model.Count)"
}
```

`$($model.Count)` — the `$()` wrapper is required for property access inside
double-quoted strings.

---

## Code Walkthrough

```powershell
$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{ Count = 0 }
        Cmd   = $null
    }
}
```

One field: `Count`, starting at zero.

```powershell
$updateFn = {
    param($msg, $model)
    switch ($msg.Key) {
        'UpArrow' {
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
            # NOTE: All other keys — pass model through unchanged.
            [PSCustomObject]@{ Model = $model; Cmd = $null }
        }
    }
}
```

Each branch constructs a fresh model. The `default` branch returns the model unchanged.

```powershell
$viewFn = {
    param($model)
    $hintStyle = New-TeaStyle -Foreground 'BrightBlack'
    New-TeaBox -Style (New-TeaStyle -Width 32 -Padding @(0, 1)) -Children @(
        New-TeaText -Content "Count: $($model.Count)"
        New-TeaText -Content '[Up] inc  [Down] dec  [Q] quit' -Style $hintStyle
    )
}
```

`New-TeaStyle` and `-Padding` are covered in detail in B-04. For now: `-Foreground 'BrightBlack'`
produces a dimmed/grey hint line, and `-Padding @(0, 1)` adds one column of left/right padding.

---

## Common Mistakes

### Missing the `default` branch

**Wrong:**
```powershell
switch ($msg.Key) {
    'UpArrow'   { [PSCustomObject]@{ Model = [PSCustomObject]@{ Count = $model.Count + 1 }; Cmd = $null } }
    'Q'         { [PSCustomObject]@{ Model = $model; Cmd = [PSCustomObject]@{ Type = 'Quit' } } }
    # no default — pressing any other key returns $null
}
```

**Right:** Always include `default { [PSCustomObject]@{ Model = $model; Cmd = $null } }`.

---

### Mutating the model and then carrying it forward

**Wrong:**
```powershell
$model.Count++
[PSCustomObject]@{ Model = $model; Cmd = $null }
```

**Right:**
```powershell
[PSCustomObject]@{
    Model = [PSCustomObject]@{ Count = $model.Count + 1 }
    Cmd   = $null
}
```

The mutation approach works (PSTea gave you a copy) but breaks down the moment your
model has multiple fields — you risk accidentally carrying over a field with a stale
value from a previous state.

---

### Forgetting `$()` in string interpolation

**Wrong:**
```powershell
New-TeaText -Content "Count: $model.Count"   # renders as "Count: @{Count=0}.Count"
```

**Right:**
```powershell
New-TeaText -Content "Count: $($model.Count)"
```

---

## Exercises

1. **Add a reset key.** Make pressing `R` reset `Count` to zero.

2. **Cap the range.** Prevent `Count` from going below 0 or above 99 using an `if`
   expression inside the `DownArrow` branch:
   ```powershell
   $newCount = if ($model.Count -gt 0) { $model.Count - 1 } else { 0 }
   ```

3. **Show min/max in the display.** Add `Min` and `Max` fields to the model (set in
   Init to `0` and `99`). Display them in View as `"Range: $($model.Min)–$($model.Max)"`.
   Enforce the cap using the model values instead of hardcoded numbers.

---

## Next Lesson

**[B-04 — Styling and Layout](04-styling-and-layout.md):** add borders, colors, and
side-by-side columns to build a properly organized TUI screen.
