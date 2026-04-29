# I-03 — Text Input

**Track:** Intermediate | **Prereqs:** I-01 — Subscriptions, I-02 — Lists

---

## Objectives

By the end of this lesson you will be able to:

- Use `New-TeaCharSub` to receive arbitrary printable characters via subscriptions
- Combine `New-TeaCharSub` with `New-TeaKeySub` for a complete text-input handler
- Track `Value` and `CursorPos` in the model for a movable text cursor
- Use `New-TeaTextInput` to render a styled text field with cursor display
- Implement Backspace, Delete, Home, End, and Left/Right cursor movement

---

## Concept

### The character sub problem

`New-TeaKeySub` binds a specific key. For text input you need to capture *any*
printable character the user types. That is what `New-TeaCharSub` is for.

```powershell
New-TeaCharSub -Handler { param($e) "Input:$([string]$e.Char)" }
```

- `-Handler` receives the raw `KeyDown` event as its first argument (`$e`)
- `$e.Char` is the typed `[char]`
- Return value is the message forwarded to Update
- Only fires for printable characters (0x0020–0x007E) that were NOT already matched
  by a `New-TeaKeySub` in the same subscription array

**Priority:** key subs take priority. If you have `New-TeaKeySub -Key 'Q' -Handler { 'Quit' }`,
pressing Q fires the key sub and the char sub does NOT fire for Q. All other printable
characters fall through to the char sub.

### Combining key subs + char sub

```powershell
$subscriptionFn = {
    param($model)
    @(
        New-TeaKeySub -Key 'Enter'      -Handler { 'Confirm' }
        New-TeaKeySub -Key 'Escape'     -Handler { 'Cancel' }
        New-TeaKeySub -Key 'Backspace'  -Handler { 'DeleteBefore' }
        New-TeaKeySub -Key 'Delete'     -Handler { 'DeleteAfter' }
        New-TeaKeySub -Key 'LeftArrow'  -Handler { 'CursorLeft' }
        New-TeaKeySub -Key 'RightArrow' -Handler { 'CursorRight' }
        New-TeaKeySub -Key 'Home'       -Handler { 'CursorHome' }
        New-TeaKeySub -Key 'End'        -Handler { 'CursorEnd' }
        # All other printable characters go here
        New-TeaCharSub -Handler { param($e) "Char:$([string]$e.Char)" }
    )
}
```

### Tracking `Value` and `CursorPos` in the model

```powershell
$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Value     = ''
            CursorPos = 0
        }
        Cmd = $null
    }
}
```

**Inserting a character at cursor:**
```powershell
$ch = $msg.Substring('Char:'.Length)   # extract the char from the message
$before = $model.Value.Substring(0, $model.CursorPos)
$after  = $model.Value.Substring($model.CursorPos)
$newValue = $before + $ch + $after
$newCursor = $model.CursorPos + 1
```

**Backspace (delete before cursor):**
```powershell
if ($model.CursorPos -gt 0) {
    $before    = $model.Value.Substring(0, $model.CursorPos - 1)
    $after     = $model.Value.Substring($model.CursorPos)
    $newValue  = $before + $after
    $newCursor = $model.CursorPos - 1
} else {
    $newValue  = $model.Value
    $newCursor = 0
}
```

**Delete (delete at cursor):**
```powershell
if ($model.CursorPos -lt $model.Value.Length) {
    $before   = $model.Value.Substring(0, $model.CursorPos)
    $after    = $model.Value.Substring($model.CursorPos + 1)
    $newValue = $before + $after
} else {
    $newValue = $model.Value
}
# CursorPos unchanged
```

**Left/Right cursor movement:**
```powershell
$newCursor = [Math]::Max(0, $model.CursorPos - 1)                   # left
$newCursor = [Math]::Min($model.Value.Length, $model.CursorPos + 1) # right
```

### `New-TeaTextInput` — the view widget

```powershell
New-TeaTextInput -Value $model.Value -CursorPos $model.CursorPos -Focused
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `-Value` | string | Current text content |
| `-CursorPos` | int | Zero-based cursor position |
| `-Focused` | switch | When present, renders the cursor character |
| `-Placeholder` | string | Shown when `Value` is empty and not focused |
| `-CursorChar` | string | Default: `'|'` |
| `-Style` | TeaStyle | Applied when not focused |
| `-FocusedStyle` | TeaStyle | Applied when focused |
| `-FocusedBoxStyle` | TeaStyle | Optional box wrapper around the field when focused |

`New-TeaTextInput` is a **view-only helper**. It does not handle key events. You own
`Value` and `CursorPos` in the model and update them in Update.

---

## Code Walkthrough

The companion script is a **live search field**. As you type, the list of colors below
is filtered to those containing the input text.

```powershell
$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Input     = ''
            CursorPos = 0
            Colors    = $using:allColors
        }
        Cmd = $null
    }
}
```

```powershell
$subscriptionFn = {
    param($model)
    @(
        New-TeaKeySub -Key 'Escape'     -Handler { 'Clear' }
        New-TeaKeySub -Key 'Backspace'  -Handler { 'DeleteBefore' }
        New-TeaKeySub -Key 'Delete'     -Handler { 'DeleteAfter' }
        New-TeaKeySub -Key 'LeftArrow'  -Handler { 'CursorLeft' }
        New-TeaKeySub -Key 'RightArrow' -Handler { 'CursorRight' }
        New-TeaKeySub -Key 'Home'       -Handler { 'CursorHome' }
        New-TeaKeySub -Key 'End'        -Handler { 'CursorEnd' }
        New-TeaKeySub -Key 'Q'          -Handler { 'Quit' }
        New-TeaCharSub -Handler { param($e) "Char:$([string]$e.Char)" }
    )
}
```

Note: Q is a key sub — pressing Q quits. If you removed that key sub, the char sub
would fire for Q and append 'q' to the input instead.

```powershell
$updateFn = {
    param($msg, $model)

    $v = $model.Value    # avoid typos in repeated references
    $c = $model.CursorPos

    switch -Wildcard ($msg) {
        'Char:*' {
            $ch     = $msg.Substring(5)
            $before = $v.Substring(0, $c)
            $after  = $v.Substring($c)
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Input     = $before + $ch + $after
                    CursorPos = $c + 1
                    Colors    = $model.Colors
                }
                Cmd = $null
            }
        }
        'DeleteBefore' {
            if ($c -gt 0) {
                $newV = $v.Substring(0, $c - 1) + $v.Substring($c)
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{ Input = $newV; CursorPos = $c - 1; Colors = $model.Colors }
                    Cmd   = $null
                }
            }
            return [PSCustomObject]@{ Model = $model; Cmd = $null }
        }
        # ... other branches in companion .ps1 ...
        'Quit' {
            return [PSCustomObject]@{ Model = $model; Cmd = [PSCustomObject]@{ Type = 'Quit' } }
        }
        default {
            return [PSCustomObject]@{ Model = $model; Cmd = $null }
        }
    }
}
```

`switch -Wildcard` lets you match `'Char:*'` patterns. Extract the character with
`.Substring(5)` (skip the `'Char:'` prefix).

In View, filter the list and pass to `New-TeaList`:

```powershell
$viewFn = {
    param($model)

    $filter    = $model.Input
    $filtered  = if ($filter -eq '') {
        $model.Colors
    } else {
        $model.Colors | Where-Object { $_ -like "*$filter*" }
    }

    $inputField = New-TeaTextInput `
        -Value       $model.Input `
        -CursorPos   $model.CursorPos `
        -Focused `
        -Placeholder 'Filter colors...' `
        -FocusedStyle (New-TeaStyle -Foreground 'BrightWhite')

    New-TeaBox -Style (New-TeaStyle -Border 'Rounded' -Width 30 -Padding @(0, 1)) -Children @(
        $inputField
        New-TeaText -Content ''
        New-TeaList -Items ($filtered -as [string[]]) -MaxVisible 12
    )
}
```

---

## Common Mistakes

### Not using `switch -Wildcard` for char messages

```powershell
# Wrong: exact match will never fire because $msg includes 'Char:' prefix
switch ($msg) {
    'a' { ... }

# Right: wildcard match on the prefix, then extract
switch -Wildcard ($msg) {
    'Char:*' { $ch = $msg.Substring(5); ... }
}
```

### Q is consumed by the char sub because the key sub is missing

If you want Q to quit, add `New-TeaKeySub -Key 'Q' -Handler { 'Quit' }` explicitly.
Without it, Q falls through to the char sub and types 'q'.

---

## Exercises

1. **Max length.** Add a `MaxLength` field to the model. In the `Char:*` branch, only
   append the character if `$model.Input.Length -lt $model.MaxLength`.

2. **Character count.** Show `"$($model.Input.Length) / $maxLength"` below the input
   field in `BrightBlack`. Update it live as the user types.

3. **Ctrl+A to select all.** Add `New-TeaKeySub -Key 'Ctrl+A' -Handler { 'Clear' }`.
   In the Clear branch, set `Input = ''` and `CursorPos = 0`.

---

## Next Lesson

**[I-04 — Focus and Forms](04-focus-and-forms.md):** build a two-field form with
Tab-based focus cycling, a text input, and a checkbox.
