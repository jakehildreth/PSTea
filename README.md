# PSTea

A PowerShell implementation of The Elm Architecture (TEA / Model-View-Update). Build interactive terminal UIs and serve those same apps in a browser via WebSocket + xterm.js without changing a line of application code. Build interactive terminal UIs and serve those same apps in a browser via WebSocket + xterm.js without changing a line of application code.

Heavily influenced by:
* [BubbleTea](https://github.com/charmbracelet/bubbletea)
* [LipGloss](https://github.com/charmbracelet/lipgloss)
* [Textual](https://github.com/Textualize/textual)
* The Commodore 64 and DOS.

---

## Quick Start

```powershell
Install-Module -Name PSTea

$Init = {
    [PSCustomObject]@{ Model = [PSCustomObject]@{ Count = 0 }; Cmd = $null }
}

$Update = {
    param($Msg, $Model)
    switch ($Msg.Key) {
        'UpArrow' { [PSCustomObject]@{ Model = [PSCustomObject]@{ Count = $Model.Count + 1 }; Cmd = $null } }
        'Q'       { [PSCustomObject]@{ Model = $Model; Cmd = [PSCustomObject]@{ Type = 'Quit' } } }
        default   { [PSCustomObject]@{ Model = $Model; Cmd = $null } }
    }
}

$View = {
    param($Model)
    New-TeaBox -Children @(
        New-TeaText -Content " Count: $($Model.Count) "
        New-TeaText -Content ' [Up] inc  [Q] quit' -Style (New-TeaStyle -Foreground 'BrightBlack')
    )
}

Start-TeaProgram -InitFn $Init -UpdateFn $Update -ViewFn $View
```

Swap `Start-TeaProgram` for `Start-TeaWebServer -Port 8080` and the exact same app runs in a browser - no code changes required.

---

## How It Works

You define three pure functions. The runtime handles the rest.

| Function | Signature | Purpose |
|---|---|---|
| `Init` | `() → Model` | Return initial application state |
| `Update` | `(Msg, Model) → Model` | Given a message, return a new model |
| `View` | `(Model) → ViewTree` | Given the current model, return a view tree |
| `Subscriptions` | `(Model) → Sub[]` | Return active event sources (keys, timers, etc.) |

Each cycle:
1. Call `View($Model)` → layout tree
2. Measure the tree (flexbox-inspired: `Fill`, `Auto`, fixed, percentage)
3. Diff against previous tree → patch list
4. Emit only changed cells as ANSI output
5. Poll subscriptions for the next message
6. Deep-copy model, call `Update($Msg, $ModelCopy)` → new model
7. Repeat

---

## View DSL

```powershell
# Text node
New-TeaText -Content 'hello' -Style $MyStyle

# Vertical box (default)
New-TeaBox -Children @($Node1, $Node2)

# Horizontal row
New-TeaRow -Children @($Node1, $Node2)
```

Width/Height values: `'Fill'`, `'Auto'`, integer (columns/rows), or `'50%'`.

---

## Styles

```powershell
$Style = New-TeaStyle `
    -Foreground '#88C0D0' `
    -Background '#2E3440' `
    -Bold `
    -Border 'Rounded' `
    -Padding 1, 2   # top/bottom=1, left/right=2

# Inherit and override
$ActiveStyle = New-TeaStyle -Base $Style -Background '#5C4AE4'
```

Border options: `None`, `Normal`, `Rounded`, `Thick`, `Double`.

Colors: hex `'#RRGGBB'`, 256-index int, or named (`Black`, `White`, `Red`, `Green`, `Blue`, `Yellow`, `Cyan`, `Magenta`, and `Bright*` variants).

---

## Subscriptions

```powershell
# Special keys (arrows, Enter, Backspace, F-keys, ctrl/shift combos)
New-TeaKeySub -OnKey {
    param($Key)
    switch ($Key) {
        'UpArrow' { [PSCustomObject]@{ Type = 'MoveUp' } }
        'ctrl+c'  { [PSCustomObject]@{ Type = 'Quit' } }
    }
}

# Printable characters (letters, digits, symbols) - for text input
New-TeaCharSub -Handler {
    param($Key)
    [PSCustomObject]@{ Type = 'CharInput'; Char = $Key.KeyChar }
}

# Timer
New-TeaTimerSub -IntervalMs 500 -OnTick {
    [PSCustomObject]@{ Type = 'Tick'; Timestamp = (Get-Date) }
}
```

`New-TeaCharSub` fires for printable ASCII (0x20-0x7E) only after all `New-TeaKeySub` handlers
have been checked. Use it alongside `New-TeaTextInput` or `New-TeaTextarea` to handle typed text.

---

## Components

Components are reusable sub-programs with their own model, update, and view - nested TEA embedded in a parent app.

```powershell
# Define a component as a plain PSCustomObject with Init/Update/View
$Counter = [PSCustomObject]@{
    Init   = { [PSCustomObject]@{ Count = 0 } }
    Update = {
        param($Msg, $Model)
        switch ($Msg.Type) {
            'Increment' { [PSCustomObject]@{ Count = $Model.Count + 1 } }
            default     { $Model }
        }
    }
    View   = {
        param($Model)
        New-TeaText -Content "Count: $($Model.Count)"
    }
}

# Parent View embeds it via New-TeaComponent
$View = {
    param($Model)
    New-TeaRow -Children @(
        New-TeaComponent -ComponentId 'left'  -SubModel $Model.LeftModel  -ViewFn $Counter.View
        New-TeaComponent -ComponentId 'right' -SubModel $Model.RightModel -ViewFn $Counter.View
    )
}

# Wrap messages for routing in parent Update
$WrappedMsg = New-TeaComponentMsg -ComponentId 'left' -Msg ([PSCustomObject]@{ Type = 'Increment' })
```

Component nodes are expanded transparently at layout time. `ConvertTo-AnsiOutput` and `Compare-TeaViewTree` never see raw `Component` nodes.

---

## Built-in Widgets

| Cmdlet | Returns | Key params |
|---|---|---|
| `New-TeaTextInput` | `Text`/`Box` | `-Value`, `-CursorPos`, `-Focused`, `-Placeholder`, `-FocusedStyle`, `-FocusedBoxStyle` |
| `New-TeaTextarea` | `Box/Vertical` | `-Lines`, `-CursorRow/-Col`, `-Focused`, `-MaxVisible`, `-ScrollOffset`, `-FocusedStyle`, `-FocusedBoxStyle` |
| `New-TeaList` | `Box/Vertical` | `-Items`, `-SelectedIndex`, `-MaxVisible`, `-Style`, `-SelectedStyle` |
| `New-TeaTable` | `Box/Vertical` | `-Headers`, `-Rows`, `-SelectedRow`, `-ColumnWidths`, `-HeaderStyle`, `-SelectedStyle` |
| `New-TeaPaginator` | `Text`/`Box` | `-CurrentPage`/`-PageCount` (numeric); `-Tabs`/`-ActiveTab` (tabs); `-Dots` (dot indicators) |
| `New-TeaSpinner` | `Text` | `-Frame`, `-Variant` (`Dots`\|`Braille`\|`Bounce`\|`Arrow`), `-Frames` |
| `New-TeaProgressBar` | `Text` | `-Value`/`-Percent`, `-Width`, `-FilledChar`, `-EmptyChar` |
| `New-TeaViewport` | `Box/Vertical` | `-Lines`, `-ScrollOffset`, `-MaxVisible` |

`-FocusedStyle` swaps foreground/background when the widget is focused. `-FocusedBoxStyle` wraps
the focused widget in a `Box` with the given style (e.g. `New-TeaStyle -Border 'Rounded'`).
Both are optional; the caller passes whatever `New-TeaStyle` produces.

---

## Web Mode

```powershell
Start-TeaWebServer `
    -Init          $Init `
    -Update        $Update `
    -View          $View `
    -Subscriptions $Subs `
    -Port          8080
```

Serves a self-contained HTML page (no CDN, bundled xterm.js) at `http://localhost:8080`. Keyboard input and ANSI output flow over a WebSocket - the application loop is identical to terminal mode.

---

## Examples

All examples are in the `Examples/` folder.

| Example | What it shows |
|---|---|
| `Invoke-IncrementDecrement` | minimal counter - the hello world of TEA |
| `Invoke-TodoList` | keyboard selection, space-to-toggle, strikethrough for done items |
| `Invoke-StyleShowcase` | every border style, text decoration, named/hex/256-index color |
| `Invoke-LayoutDemo` | two-pane row layout with nav menu and dynamic content panel |
| `Invoke-ComponentDemo` | two independent counters as components, Tab to switch focus |
| `Invoke-WidgetShowcaseDemo` | all Phase 9+10 widgets with live-adjustable config options |
| `Invoke-ColorPickerDemo` | 256-color palette browser, arrow-key navigation |
| `Invoke-PomodoroDemo` | Pomodoro timer with spinner, progress bar, and timer subscription |
| `Invoke-StopwatchDemo` | stopwatch with lap tracking and tick-driven animation |
| `Invoke-QuizDemo` | multiple-choice quiz with list widget and score tracking |
| `Invoke-FileExplorerDemo` | scrollable directory tree with viewport and keyboard navigation |
| `Invoke-SnakeDemo` | Snake game - real-time tick-driven movement and collision detection |
| `Invoke-SystemMonitorDemo` | live CPU/memory stats via timer subscription |

---

## Requirements

- PowerShell 5.1+ (Windows) or PowerShell 7+ (cross-platform)
- No external dependencies

---

## Installation

```powershell
# PowerShell Gallery (coming soon)
Install-Module -Name PSTea

# From source
git clone https://github.com/jakehildreth/PSTea.git
Import-Module ./PSTea/PSTea.psd1
```

---

## License

MIT License w/Commons Clause - see [LICENSE](./LICENSE) file for details.

---

Made with 💜 by [Jake Hildreth](https://jakehildreth.com)
