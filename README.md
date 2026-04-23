# Elm

An implementation of the [Elm Architecture](https://guide.elm-lang.org/architecture/) (Model-View-Update / TEA) as a PowerShell module. Build interactive terminal UIs — and serve those same apps in a browser via WebSocket + xterm.js — without changing a line of application code.

Heavily influenced by [BubbleTea](https://github.com/charmbracelet/bubbletea), [LipGloss](https://github.com/charmbracelet/lipgloss), and [Textual](https://github.com/Textualize/textual).

---

## Quick Start

```powershell
Install-Module -Name Elm

$Init = { [PSCustomObject]@{ Count = 0 } }

$Update = {
    param($Msg, $Model)
    switch ($Msg.Type) {
        'Increment' { [PSCustomObject]@{ Count = $Model.Count + 1 } }
        default     { $Model }
    }
}

$View = {
    param($Model)
    New-ElmBox -Children @(
        New-ElmText -Content " Count: $($Model.Count) "
        New-ElmText -Content ' [+] increment  [q] quit'
    )
}

$Subs = {
    param($Model)
    @(
        New-ElmKeySub -OnKey {
            param($Key)
            switch ($Key) {
                '+'  { [PSCustomObject]@{ Type = 'Increment' } }
                'q'  { [PSCustomObject]@{ Type = 'Quit' } }
            }
        }
    )
}

Start-ElmProgram -Init $Init -Update $Update -View $View -Subscriptions $Subs
```

Swap `Start-ElmProgram` for `Start-ElmWebServer -Port 8080` and the exact same app runs in a browser — no code changes required.

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
New-ElmText -Content 'hello' -Style $MyStyle

# Vertical box (default)
New-ElmBox -Children @($Node1, $Node2)

# Horizontal row
New-ElmRow -Children @($Node1, $Node2)
```

Width/Height values: `'Fill'`, `'Auto'`, integer (columns/rows), or `'50%'`.

---

## Styles

```powershell
$Style = New-ElmStyle `
    -Foreground '#88C0D0' `
    -Background '#2E3440' `
    -Bold `
    -Border 'Rounded' `
    -Padding 1, 2   # top/bottom=1, left/right=2

# Inherit and override
$ActiveStyle = New-ElmStyle -Base $Style -Background '#5C4AE4'
```

Border options: `None`, `Normal`, `Rounded`, `Thick`, `Double`.

Colors: hex `'#RRGGBB'`, 256-index int, or named (`Black`, `White`, `Red`, `Green`, `Blue`, `Yellow`, `Cyan`, `Magenta`, and `Bright*` variants).

---

## Subscriptions

```powershell
# Keyboard
New-ElmKeySub -OnKey {
    param($Key)
    switch ($Key) {
        'UpArrow' { [PSCustomObject]@{ Type = 'MoveUp' } }
        'ctrl+c'  { [PSCustomObject]@{ Type = 'Quit' } }
    }
}

# Timer
New-ElmTimerSub -Interval ([TimeSpan]::FromMilliseconds(500)) -OnTick {
    [PSCustomObject]@{ Type = 'Tick'; Timestamp = (Get-Date) }
}
```

---

## Built-in Widgets

| Cmdlet | Description |
|---|---|
| `New-ElmTextInput` | Single-line text input |
| `New-ElmList` | Scrollable, selectable list |
| `New-ElmSpinner` | Animated spinner (tick-driven) |
| `New-ElmProgressBar` | Percent-fill progress bar |
| `New-ElmViewport` | Scrollable text viewport |

---

## Web Mode

```powershell
Start-ElmWebServer `
    -Init          $Init `
    -Update        $Update `
    -View          $View `
    -Subscriptions $Subs `
    -Port          8080
```

Serves a self-contained HTML page (no CDN, bundled xterm.js) at `http://localhost:8080`. Keyboard input and ANSI output flow over a WebSocket — the application loop is identical to terminal mode.

---

## Requirements

- PowerShell 5.1+ (Windows) or PowerShell 7+ (cross-platform)
- No external dependencies

---

## Installation

```powershell
# PowerShell Gallery (coming soon)
Install-Module -Name Elm

# From source
git clone https://github.com/jakehildreth/Elm.git
Import-Module ./Elm/Elm.psd1
```

---

## License

MIT License w/Commons Clause - see [LICENSE](./LICENSE) file for details.

---

Made with 💜 by [Jake Hildreth](https://jakehildreth.com)
