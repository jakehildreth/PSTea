# I-02 — Lists and Navigation

**Track:** Intermediate | **Prereqs:** I-01 — Subscriptions

---

## Objectives

By the end of this lesson you will be able to:

- Use `New-TeaList` to render a scrollable, highlighted list
- Track `SelectedIndex` in the model and wire Up/Down arrow subs to move it
- Implement wrap-around navigation (`($i + 1) % $count`)
- Style the selected item dynamically using model state
- Show a detail panel next to a list using `New-TeaRow`

---

## Concept

### `New-TeaList`

```powershell
New-TeaList -Items @('Alpha', 'Beta', 'Gamma') -SelectedIndex $model.Cursor -MaxVisible 5
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Items` | string[] | required | Array of display strings |
| `-SelectedIndex` | int | 0 | Zero-based index of the highlighted row |
| `-MaxVisible` | int | 10 | Window height (auto-scrolls) |
| `-Prefix` | string | `'> '` | Prepended to the selected row |
| `-UnselectedPrefix` | string | `'  '` | Prepended to unselected rows |
| `-Style` | TeaStyle | — | Applied to unselected rows |
| `-SelectedStyle` | TeaStyle | bold | Applied to the selected row |

You own `SelectedIndex` in the model. `New-TeaList` does not move the cursor — it
only renders whatever index you give it.

### Tracking the cursor

```powershell
$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Items  = @('Red', 'Green', 'Blue')
            Cursor = 0
        }
        Cmd = $null
    }
}
```

In Update, move the cursor and clamp or wrap as needed:

```powershell
'MoveDown' {
    $next = ($model.Cursor + 1) % $model.Items.Count  # wraps around
    return [PSCustomObject]@{
        Model = [PSCustomObject]@{ Items = $model.Items; Cursor = $next }
        Cmd   = $null
    }
}
```

### Wrap-around vs clamped navigation

**Wrap-around** — going past the last item returns to the first:
```powershell
$next = ($model.Cursor + 1) % $model.Items.Count
$prev = ($model.Cursor - 1 + $model.Items.Count) % $model.Items.Count
```

**Clamped** — stops at the first/last item:
```powershell
$next = [Math]::Min($model.Cursor + 1, $model.Items.Count - 1)
$prev = [Math]::Max($model.Cursor - 1, 0)
```

Use wrap-around for menus and color pickers.
Use clamped for lists where the position within the list is semantically meaningful
(e.g., a file list where top/bottom are distinct boundaries).

### Accessing the selected item

```powershell
$selected = $model.Items[$model.Cursor]
```

### Side-by-side list + detail panel

```powershell
$viewFn = {
    param($model)
    $selected = $model.Items[$model.Cursor]
    New-TeaRow -Children @(
        New-TeaBox -Style (New-TeaStyle -Width 24 -Border 'Rounded') -Children @(
            New-TeaList -Items $model.Items -SelectedIndex $model.Cursor -MaxVisible 10
        )
        New-TeaBox -Style (New-TeaStyle -Width 30 -Border 'Rounded' -MarginLeft 2) -Children @(
            New-TeaText -Content "Selected: $selected"
        )
    )
}
```

---

## Code Walkthrough

The companion script shows all 16 named colors as a navigable list. The selected color
name is shown in its own color in the right panel.

```powershell
$colors = @(
    'Black', 'Red', 'Green', 'Yellow',
    'Blue', 'Magenta', 'Cyan', 'White',
    'BrightBlack', 'BrightRed', 'BrightGreen', 'BrightYellow',
    'BrightBlue', 'BrightMagenta', 'BrightCyan', 'BrightWhite'
)

$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Items  = $using:colors   # NOTE: see below about closures
            Cursor = 0
        }
        Cmd = $null
    }
}
```

**Note on `$using:` in scriptblocks:** Scriptblock parameters to `Start-TeaProgram`
run inside a runspace. To capture a variable from the outer scope, use the `$using:`
scope prefix. This is also why constants like the color list are defined outside the
scriptblocks and referenced with `$using:colors`.

```powershell
$subscriptionFn = {
    param($model)
    @(
        New-TeaKeySub -Key 'UpArrow'   -Handler { 'MoveUp' }
        New-TeaKeySub -Key 'DownArrow' -Handler { 'MoveDown' }
        New-TeaKeySub -Key 'Q'         -Handler { 'Quit' }
    )
}
```

```powershell
$updateFn = {
    param($msg, $model)
    $count = $model.Items.Count
    switch ($msg) {
        'MoveUp' {
            $prev = ($model.Cursor - 1 + $count) % $count
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{ Items = $model.Items; Cursor = $prev }
                Cmd   = $null
            }
        }
        'MoveDown' {
            $next = ($model.Cursor + 1) % $count
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{ Items = $model.Items; Cursor = $next }
                Cmd   = $null
            }
        }
        'Quit' {
            return [PSCustomObject]@{ Model = $model; Cmd = [PSCustomObject]@{ Type = 'Quit' } }
        }
        default {
            return [PSCustomObject]@{ Model = $model; Cmd = $null }
        }
    }
}
```

```powershell
$viewFn = {
    param($model)
    $selected     = $model.Items[$model.Cursor]
    $selStyle     = New-TeaStyle -Foreground $selected -Bold
    $hintStyle    = New-TeaStyle -Foreground 'BrightBlack'
    $previewStyle = New-TeaStyle -Foreground $selected -Bold

    New-TeaRow -Children @(
        New-TeaBox -Style (New-TeaStyle -Border 'Rounded' -Width 22 -Padding @(0, 1)) -Children @(
            New-TeaList -Items $model.Items -SelectedIndex $model.Cursor -MaxVisible 8 -SelectedStyle $selStyle
        )
        New-TeaBox -Style (New-TeaStyle -Border 'Rounded' -Width 24 -MarginLeft 2 -Padding @(1, 2)) -Children @(
            New-TeaText -Content $selected -Style $previewStyle
            New-TeaText -Content ''
            New-TeaText -Content "Index: $($model.Cursor)" -Style (New-TeaStyle -Foreground 'BrightBlack')
        )
    )
    New-TeaText -Content '[Up/Down] navigate  [Q] quit' -Style $hintStyle
}
```

The selected color name is used as both the `-Foreground` value for the highlight style
AND as the display text in the preview panel. Each color in the list renders in its own
color when selected.

---

## Common Mistakes

### Hardcoding item count

```powershell
# Wrong — breaks if Items changes size
$next = ($model.Cursor + 1) % 16

# Right — always correct
$next = ($model.Cursor + 1) % $model.Items.Count
```

### Off-by-one in upward wrap

```powershell
# Wrong — goes to -1 when cursor is at 0
$prev = ($model.Cursor - 1) % $count

# Right — stays non-negative
$prev = ($model.Cursor - 1 + $count) % $count
```

### Passing a PSCustomObject array to `-Items` instead of strings

`New-TeaList` expects `[string[]]`. If your model stores objects, project to strings first:

```powershell
New-TeaList -Items ($model.Tasks | ForEach-Object { $_.Title }) -SelectedIndex $model.Cursor
```

---

## Exercises

1. **Enter to select.** Add an `'Enter'` key sub that sets `model.Selected` to the
   currently highlighted item string and displays it in the detail panel in bold.

2. **Filter.** Add a `Filter` string to the model. Display only items that contain
   `$model.Filter` (case-insensitive). Recalculate filtered items in View using
   `Where-Object`. The cursor should reset when the filter changes (I-03 text input
   can drive the filter value).

3. **Clamped navigation.** Replace the wrap-around with clamped navigation. Add a
   scroll indicator: `"$($model.Cursor + 1) / $($model.Items.Count)"`.

---

## Next Lesson

**[I-03 — Text Input](03-text-input.md):** accept free-form text with cursor movement
using `New-TeaCharSub`, `New-TeaKeySub`, and `New-TeaTextInput`.
