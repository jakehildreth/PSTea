# I-04 — Focus and Forms

**Track:** Intermediate | **Prereqs:** I-01, I-02, I-03

---

## Objectives

By the end of this lesson you will be able to:

- Use a `Focus` field in the model to track which form control is active
- Route key events to the focused field only
- Build a two-field form with a text input and a manual checkbox
- Cycle focus between fields with the Tab key
- Visually distinguish the focused field with a border or color change
- Submit or read form values from the final model

---

## Concept

### Focus as a model field

PSTea has no built-in focus system. You implement it yourself using a string (or enum)
field in the model:

```powershell
$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Focus = 'Name'   # which field has keyboard focus
            # ... other fields
        }
        Cmd = $null
    }
}
```

In Update, check `$model.Focus` before handling key events. A key press on the text
input field does nothing when focus is on the checkbox, and vice versa.

### Tab cycling

Tab rotates through the available focus targets in a fixed order:

```powershell
'Tab' {
    $next = switch ($model.Focus) {
        'Name'        { 'Subscribed' }
        'Subscribed'  { 'Name' }
        default       { 'Name' }
    }
    return [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Focus       = $next
            # ... carry all other fields
        }
        Cmd = $null
    }
}
```

### Routing events to the focused field

The cleanest pattern: check focus at the top of Update, before the main `switch`.

```powershell
$updateFn = {
    param($msg, $model)

    # --- Spacebar toggles the checkbox --- (only when focused)
    if ($model.Focus -eq 'Subscribed' -and $msg -eq 'Toggle') {
        return [PSCustomObject]@{
            Model = [PSCustomObject]@{
                Focus      = $model.Focus
                Name       = $model.Name
                NameCursor = $model.NameCursor
                Subscribed = -not $model.Subscribed
            }
            Cmd = $null
        }
    }

    # --- Character input goes to the Name field --- (only when focused)
    if ($model.Focus -eq 'Name') {
        switch -Wildcard ($msg) {
            'Char:*' { ... }
            'DeleteBefore' { ... }
            # ...
        }
    }

    # --- Global keys ---
    switch ($msg) {
        'Tab'  { ... }
        'Quit' { ... }
        default { return [PSCustomObject]@{ Model = $model; Cmd = $null } }
    }
}
```

### Manual checkbox (no built-in widget)

PSTea does not (yet) have a `New-TeaCheckbox` widget. Build one manually with
`New-TeaText` and a boolean model field:

```powershell
$checkboxText = if ($model.Subscribed) { '[x] Subscribe to updates' } else { '[ ] Subscribe to updates' }

$checkboxStyle = if ($model.Focus -eq 'Subscribed') {
    New-TeaStyle -Foreground 'BrightWhite' -Bold
} else {
    New-TeaStyle -Foreground 'White'
}

New-TeaText -Content $checkboxText -Style $checkboxStyle
```

Press Space to toggle when the checkbox has focus.

### Conditional focus styling in View

Use the focus field to change the style of the focused element:

```powershell
$nameFocused = $model.Focus -eq 'Name'

New-TeaTextInput `
    -Value        $model.Name `
    -CursorPos    $model.NameCursor `
    -Focused:$nameFocused `
    -Placeholder  'Your name...' `
    -FocusedBoxStyle (New-TeaStyle -Border 'Rounded' -Foreground 'BrightCyan')
```

When `-Focused` is `$false`, `New-TeaTextInput` renders without the cursor character.
When it is `$true`, the cursor is visible and `FocusedBoxStyle` (if provided) wraps the field.

---

## Code Walkthrough

The companion script is a two-field contact form: **Name** (text input) +
**Subscribe** (checkbox). Tab moves focus; Enter submits.

```
╭─────────────────────────────────────╮
│  Contact Form                       │
│                                     │
│  Name                               │
│  ╭──────────────────────────╮       │
│  │ Jake|                    │       │  ← focused field has Rounded border
│  ╰──────────────────────────╯       │
│                                     │
│  [ ] Subscribe to updates           │  ← unfocused checkbox
│                                     │
│  [Tab] next field  [Q] quit         │
╰─────────────────────────────────────╯
```

When the checkbox has focus, `[x]`/`[ ]` is bolded and Space toggles it.

```powershell
$subscriptionFn = {
    param($model)
    $subs = @(
        New-TeaKeySub -Key 'Tab'      -Handler { 'Tab' }
        New-TeaKeySub -Key 'Spacebar' -Handler { 'Toggle' }
        New-TeaKeySub -Key 'Q'        -Handler { 'Quit' }
        New-TeaKeySub -Key 'Backspace' -Handler { 'DeleteBefore' }
        New-TeaKeySub -Key 'LeftArrow'  -Handler { 'CursorLeft' }
        New-TeaKeySub -Key 'RightArrow' -Handler { 'CursorRight' }
    )
    # Only add char sub when Name field is focused — prevents typing when on checkbox
    if ($model.Focus -eq 'Name') {
        $subs += New-TeaCharSub -Handler { param($e) "Char:$([string]$e.Char)" }
    }
    $subs
}
```

Conditionally adding the char sub to `$subscriptionFn` is a clean alternative to
routing inside Update: the char sub simply does not fire when the checkbox has focus.

---

## Common Mistakes

### Global char sub when you only want input in one field

If the char sub is always present, pressing any key while on the checkbox will also
trigger it. Always make the char sub conditional (either in `SubscriptionFn` or via
an `if ($model.Focus -eq ...)` guard in Update).

### Forgetting to carry all fields in the new model

Because every Update branch constructs a new model, you must explicitly carry forward
**all** fields — including `Focus` and `NameCursor` — in every branch, even those that
do not change them. A helper function can reduce this repetition:

```powershell
function New-Model {
    param($Current, [hashtable]$Overrides)
    $props = @{}
    $Current.PSObject.Properties | ForEach-Object { $props[$_.Name] = $_.Value }
    foreach ($k in $Overrides.Keys) { $props[$k] = $Overrides[$k] }
    [PSCustomObject]$props
}
```

Then: `New-Model -Current $model -Overrides @{ Subscribed = $true }`.

---

## Exercises

1. **Third field.** Add an `Email` text-input field. Tab cycles: Name → Email →
   Subscribed → Name. Show the email field between Name and Subscribed in View.

2. **Enter to submit.** Add `New-TeaKeySub -Key 'Enter' -Handler { 'Submit' }`.
   When submitted, display a "Submitted!" confirmation line and prevent further editing
   by checking a `model.Submitted` flag in SubscriptionFn.

3. **Validation.** Before allowing Submit, validate that Name is non-empty. If it is
   empty, display `'Name is required'` in `BrightRed` below the Name field instead
   of submitting.

---

## Next Lesson

**[I-05 — Capstone: Note Taker](05-capstone-note-taker.md):** combine lists, text
input, focus, and forms into a multi-note CRUD application.
