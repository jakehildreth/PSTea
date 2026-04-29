# A-02 — Power Widgets

**Track:** Advanced | **Prereqs:** A-01 — Components

---

## Objectives

By the end of this lesson you will be able to:

- Use `New-TeaProgressBar` to display a percentage fill bar
- Use `New-TeaSpinner` to render an animated spinner driven by a frame counter
- Use `New-TeaTable` to display tabular data with a selectable row
- Use `New-TeaViewport` to display a scrollable window into an array of lines
- Use `New-TeaTextarea` to render a multi-line editable text area
- Use `New-TeaPaginator` to render a page indicator, dot bar, or tab bar

---

## Widget Reference

### `New-TeaProgressBar`

Renders a horizontal filled bar: `[########--------]`.

```powershell
# 0.0 – 1.0 ratio
New-TeaProgressBar -Value 0.75 -Width 30

# 0 – 100 percent
New-TeaProgressBar -Percent 50 -Width 20 -Style (New-TeaStyle -Foreground 'BrightGreen')
```

| Parameter | Default | Notes |
|-----------|---------|-------|
| `-Value` | required (ratio set) | 0.0–1.0, clamped |
| `-Percent` | required (percent set) | 0–100 |
| `-Width` | 20 | Total width including `[ ]` brackets |
| `-FilledChar` | `'#'` | Character for the filled portion |
| `-EmptyChar` | `'-'` | Character for the empty portion |
| `-Style` | — | Applied to the whole bar |

---

### `New-TeaSpinner`

Renders one frame of a cycling animation. You own the frame counter in the model.

```powershell
New-TeaSpinner -Frame $model.TickCount
New-TeaSpinner -Frame $model.Frame -Variant 'Braille' -Style (New-TeaStyle -Foreground 'BrightCyan')
New-TeaSpinner -Frame $model.Frame -Frames @('>', '>>', '>>>', '>>', '>')
```

Built-in variants: `Dots` (default) `|/-\`, `Braille` ⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏, `Bounce` `. o O o`, `Arrow` `> >> >>> >> >`.

Increment `Frame` via a timer subscription:

```powershell
New-TeaTimerSub -IntervalMs 100 -Handler { 'Tick' }
# In Update:
'Tick' { [PSCustomObject]@{ ... Frame = $model.Frame + 1 } }
```

---

### `New-TeaTable`

Renders tabular data with auto-sized columns and optional row selection.

```powershell
$params = @{
    Headers       = @('Name', 'Age', 'City')
    Rows          = @(@('Alice', '30', 'New York'), @('Bob', '25', 'London'))
    SelectedRow   = $model.Cursor
    HeaderStyle   = New-TeaStyle -Foreground 'BrightCyan' -Bold
    SelectedStyle = New-TeaStyle -Foreground 'BrightYellow'
}
New-TeaTable @params
```

| Parameter | Default | Notes |
|-----------|---------|-------|
| `-Headers` | — | Column header strings. When omitted, no header row is rendered |
| `-Rows` | required | `[string[][]]` — each element is a row array |
| `-SelectedRow` | -1 | Zero-based index. -1 = no selection |
| `-ColumnWidths` | auto | Override column widths |

Track `Cursor` in the model; navigate with Up/Down subscriptions.

---

### `New-TeaViewport`

Shows a fixed-height window into an array of lines. The caller manages `ScrollOffset`.

```powershell
New-TeaViewport -Lines $model.LogLines -ScrollOffset $model.ScrollPos -MaxVisible 20
```

Scroll down: `$newScroll = [Math]::Min($model.ScrollPos + 1, $model.LogLines.Count - $MaxVisible)`  
Scroll to bottom: `[Math]::Max(0, $lines.Count - $MaxVisible)`

---

### `New-TeaTextarea`

Multi-line editable text. The caller manages `Lines` (string array), `CursorRow`,
`CursorCol`, and `ScrollOffset`.

```powershell
New-TeaTextarea `
    -Lines        $model.BodyLines `
    -CursorRow    $model.CursorRow `
    -CursorCol    $model.CursorCol `
    -Focused `
    -MaxVisible   8 `
    -FocusedBoxStyle (New-TeaStyle -Border 'Rounded' -Foreground 'BrightWhite')
```

Key handling for Enter (new line):

```powershell
'NewLine' {
    $r = $model.CursorRow
    $c = $model.CursorCol
    $before = $model.BodyLines[$r].Substring(0, $c)
    $after  = $model.BodyLines[$r].Substring($c)
    $lines  = @($model.BodyLines[0..($r - 1)]) + @($before) + @($after) + @($model.BodyLines[($r + 1)..($model.BodyLines.Count - 1)])
    return [PSCustomObject]@{ ... Lines = $lines; CursorRow = $r + 1; CursorCol = 0 }
}
```

---

### `New-TeaPaginator`

Three modes: numeric, dots, named tabs.

```powershell
# Numeric: < 3 / 7 >
New-TeaPaginator -CurrentPage $model.Page -PageCount 7

# Dots: ○ ○ ● ○
New-TeaPaginator -CurrentPage $model.Page -PageCount 4 -Dots

# Named tabs: Tab1 | [Tab2] | Tab3
New-TeaPaginator -Tabs @('Overview', 'Details', 'Logs') -ActiveTab $model.Tab
```

---

## Code Walkthrough

The companion script is a tabbed showcase. P/N or Left/Right arrows cycle through
six panels — one per widget. `New-TeaPaginator -Tabs` renders the tab bar at the top.

```powershell
$tabs = @('Progress', 'Spinner', 'Table', 'Viewport', 'Textarea', 'Paginator')

$subscriptionFn = {
    param($model)
    $subs = @(
        New-TeaKeySub -Key 'N'          -Handler { 'NextTab' }
        New-TeaKeySub -Key 'P'          -Handler { 'PrevTab' }
        New-TeaKeySub -Key 'RightArrow' -Handler { 'NextTab' }
        New-TeaKeySub -Key 'LeftArrow'  -Handler { 'PrevTab' }
        New-TeaKeySub -Key 'UpArrow'    -Handler { 'ScrollUp' }
        New-TeaKeySub -Key 'DownArrow'  -Handler { 'ScrollDown' }
        New-TeaKeySub -Key 'Q'          -Handler { 'Quit' }
        New-TeaTimerSub -IntervalMs 80  -Handler { 'Tick' }
    )
    $subs
}
```

In View, `switch ($model.Tab)` selects which panel content to render.

---

## Common Mistakes

### Passing a float to `-Percent`

`-Percent` expects an `[int]` 0–100. Compute the integer first:

```powershell
$pct = [int]($model.Done / $model.Total * 100)
New-TeaProgressBar -Percent $pct -Width 30
```

### Forgetting to tick the spinner frame

`New-TeaSpinner` renders the correct frame only when `Frame` is incremented. Without
a timer subscription, the spinner displays a static frame.

### Table rows not as string arrays

```powershell
# Wrong: rows are PSCustomObjects, not string arrays
$rows = $model.Users | ForEach-Object { $_ }

# Right: project to string arrays
$rows = $model.Users | ForEach-Object { @($_.Name, [string]$_.Age, $_.City) }
```

---

## Exercises

1. **Progress bar driven by a timer.** Add a `Progress` field (0.0–1.0) to the model.
   Each Tick increments it by `0.02`. When it reaches 1.0, reset to 0.0.

2. **Textarea Enter key.** In the Textarea panel, implement a `NewLine` sub using the
   array split pattern described above.

3. **Tab keyboard shortcuts.** Instead of N/P for tab navigation, use `1`–`6` to jump
   directly to each tab. Use `New-TeaKeySub -Key 'D1' -Handler { 'Tab:0' }` etc.

---

## Next Lesson

**[A-03 — Timer-Driven UIs](03-timer-driven-uis.md):** build a live clock + pause/resume
using `New-TeaTimerSub`, `New-TeaSpinner`, and conditional subscriptions.
