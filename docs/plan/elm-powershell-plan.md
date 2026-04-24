# Plan: PowerShell Elm Architecture (TEA/MVU TUI + Web Framework)

## Problem Statement

Implement the Elm Architecture (The Elm Architecture / Model-View-Update) as a PowerShell module
targeting PS 5.1+ on Windows, with cross-platform support via PS 7+. The result is a framework for
building interactive terminal user interfaces — and serving those same apps in a browser via
WebSocket + xterm.js — without changing a line of application code.

Developers define three pure functions and hand them to a runtime:

```powershell
Start-ElmProgram `
    -Init          { [PSCustomObject]@{ Count = 0 } } `
    -Update        $UpdateFn `
    -View          $ViewFn `
    -Subscriptions $SubsFn

# OR serve the exact same app in a browser:
Start-ElmWebServer `
    -Init          { [PSCustomObject]@{ Count = 0 } } `
    -Update        $UpdateFn `
    -View          $ViewFn `
    -Subscriptions $SubsFn `
    -Port          8080
```

---

## Design Influences

| Framework    | Language | Influence |
|---|---|---|
| **BubbleTea** | Go | Direct TEA implementation in a terminal context — validates the architecture |
| **Bubbles**   | Go | Pre-built reusable component library (TextInput, List, Viewport, Spinner, ProgressBar) |
| **LipGloss**  | Go | CSS-inspired style API: truecolor/256-color, borders, padding, margin, alignment |
| **Textual**   | Python | Flexbox-ish layout engine; web app serving via WebSocket + xterm.js |

---

## Decisions

| Concern | Decision | Rationale |
|---|---|---|
| Architecture | Elm Architecture (MVU) | Pure functions, predictable state, highly testable |
| Scope | MVU + subs + style + components + widgets + web serving | Matches BubbleTea/Bubbles/LipGloss feature parity |
| Target runtime | PS 5.1+ (Windows), PS 7+ (cross-platform) | Per Jake's standards |
| Rendering | ANSI escape codes | Cross-platform, zero native deps, xterm.js-compatible |
| Virtual terminal | P/Invoke `SetConsoleMode` + `ENABLE_VIRTUAL_TERMINAL_PROCESSING` | Required for ANSI in conhost on Windows; no-op on PS7/Linux/macOS |
| Diff strategy | Diff-based (compare-and-patch) | Only redraw changed cells; reduces flicker and I/O |
| Model type | PSCustomObject | Most readable for intermediate PS devs; dot-access syntax |
| Model mutation | Runtime deep-copies before each `Update` call | Enforces Elm's immutability contract |
| Layout | Flexbox-inspired: `Fill`, `Auto`, fixed int, percentage | Enables responsive-ish TUI layouts |
| I/O architecture | Driver abstraction via `ConcurrentQueue[string]` | Decouples event loop from I/O; same loop works for terminal and WebSocket |
| Web serving | `System.Net.HttpListener` WebSocket + embedded xterm.js | Available in .NET 4.5+ (PS 5.1); no external dependencies |
| Methodology | TDD — tests written before every function | Non-negotiable per Jake's standards |
| Commit policy | Draft commit → Jake approval → push | Per Jake's standards |
| Versioning | CalVer (yyyy.M.dHHmm) | Per Jake's standards |
| Input normalization | Normalize at driver (Option A): each driver converts raw input to a canonical string format before enqueuing | Single testable format; failures isolate to driver lookup tables; queue contents are inspectable for debugging |
| InputQueue ownership | `Invoke-ElmSubscriptions` is the sole `$InputQueue` dequeuer; event loop never calls `TryDequeue` directly | Eliminates double-consumer race; `Quit` becomes a normal subscription message handled uniformly |
| ANSI output functions | Two functions: `ConvertTo-AnsiOutput -Root` (full frame) and `ConvertTo-AnsiPatch -Patches` (incremental) | Single responsibility; first-render detection belongs to the caller, not the function |
| Subscription state cache | `$SubCache` hashtable owned by the event loop; passed to `Invoke-ElmSubscriptions` each cycle | Timer `$LastFired` persists across cycles without polluting immutable subscription objects |
| Terminal dimensions | `$W`/`$H` initialized from `[Console]::WindowWidth/Height` before loop starts; `Resize` canonical message updates them and forces `FullRedraw` | Dimensions always current; WebSocket resize handled identically via canonical `Resize` message |

---

## How It Works: End-to-End Walk-Through

### Developer Writes

```powershell
# 1. Init: return the initial model
$Init = {
    [PSCustomObject]@{
        Items    = @('Apples', 'Bananas', 'Cherries')
        Selected = 0
    }
}

# 2. Update: pure function — given a Msg and current Model, return a new Model
$Update = {
    param(
        [Parameter(Mandatory)] $Msg,
        [Parameter(Mandatory)] $Model
    )
    switch ($Msg.Type) {
        'MoveUp' {
            $NewSelected = [Math]::Max(0, $Model.Selected - 1)
            [PSCustomObject]@{ Items = $Model.Items; Selected = $NewSelected }
        }
        'MoveDown' {
            $NewSelected = [Math]::Min($Model.Items.Count - 1, $Model.Selected + 1)
            [PSCustomObject]@{ Items = $Model.Items; Selected = $NewSelected }
        }
        default { $Model }
    }
}

# 3. View: pure function — given Model, return a view tree
$View = {
    param([Parameter(Mandatory)] $Model)

    $HeaderStyle   = New-ElmStyle -Bold -Foreground '#FFFFFF' -Background '#5C4AE4'
    $SelectedStyle = New-ElmStyle -Bold -Foreground '#000000' -Background '#88C0D0'

    $Rows = for ($i = 0; $i -lt $Model.Items.Count; $i++) {
        $Style = if ($i -eq $Model.Selected) { $SelectedStyle } else { $null }
        New-ElmText -Content "  $($Model.Items[$i]) " -Style $Style
    }

    New-ElmBox -Children @(
        New-ElmText -Content ' My List ' -Style $HeaderStyle
        New-ElmBox -Children $Rows
        New-ElmText -Content ' [up/down] navigate  [q] quit'
    )
}

# 4. Subscriptions: return a list of active event sources
$Subs = {
    param([Parameter(Mandatory)] $Model)
    @(
        New-ElmKeySub -OnKey {
            param([Parameter(Mandatory)] $Key)
            switch ($Key) {
                'UpArrow'   { [PSCustomObject]@{ Type = 'MoveUp' } }
                'DownArrow' { [PSCustomObject]@{ Type = 'MoveDown' } }
                'q'         { [PSCustomObject]@{ Type = 'Quit' } }
            }
        }
    )
}

# 5. Run
Start-ElmProgram -Init $Init -Update $Update -View $View -Subscriptions $Subs
```

### What the Runtime Does Each Cycle

```
1.  Call Init()                         → $Model
2.  Call View($Model)                   → $ViewTree
3.  Measure-ElmViewTree($ViewTree)      → $MeasuredTree  (X, Y, Width, Height on each node)
4.  Compare-ElmViewTree($Prev, $Measured) → $Patches
5.  Convert patches → $AnsiString
6.  Push $AnsiString → OutputQueue      → driver writes to terminal or WebSocket
7.  $PrevTree = $MeasuredTree
8.  Poll InputQueue / Subscriptions for next event
9.  $ModelCopy = Copy-ElmModel($Model)
10. $Model = Update($Msg, $ModelCopy)
11. Goto 2
```

---

## Architecture: Layers

```
╔══════════════════════════════════════════════════════════╗
║  User Application Code                                   ║
║  Init / Update / View / Subscriptions scriptblocks       ║
╚══════════════════════════════════╤═══════════════════════╝
                                   │
╔══════════════════════════════════▼═══════════════════════╗
║  Runtime  (Invoke-ElmEventLoop)                          ║
║  Calls Init, View, Update, Subscriptions                 ║
║  Deep-copies model before each Update                    ║
║  Reads InputQueue / writes OutputQueue only              ║
╚══════════╤═══════════════════╤═══════════════════════════╝
           │                   │
╔══════════▼═══╗    ╔══════════▼════════════════════════╗
║  View Layer  ║    ║  Subscription Layer               ║
║  DSL nodes   ║    ║  Invoke-ElmSubscriptions          ║
║  Measure     ║    ║  New-ElmKeySub (Console.ReadKey)  ║
║  Diff        ║    ║  New-ElmTimerSub (Timers.Timer)   ║
║  ANSI emit   ║    ╚═══════════════════════════════════╝
╚══════════════╝
           │
╔══════════▼══════════════════════════════════════════════╗
║  Driver Abstraction  (ConcurrentQueue[string])          ║
║  InputQueue  ← keyboard events (ANSI key strings)       ║
║  OutputQueue → rendered ANSI frames                     ║
╚══════════╤══════════════════════════════════════════════╝
           │
     ┌─────┴──────┐
     ▼            ▼
 Terminal      WebSocket
  Driver        Driver
 stdout /     HttpListener
 ReadKey       + xterm.js
```

---

## View Tree Schema

All view nodes are `PSCustomObject`. The runtime validates shape on each cycle.

### Text Node

```powershell
[PSCustomObject]@{
    Type    = 'Text'         # string, required
    Content = 'hello'        # string, required
    Style   = $null          # ElmStyle PSCustomObject or $null
}
```

### Box Node (vertical or horizontal)

```powershell
[PSCustomObject]@{
    Type      = 'Box'           # string, required
    Direction = 'Vertical'      # 'Vertical' or 'Horizontal', required
    Children  = @(...)          # array of view nodes, required
    Style     = $null           # ElmStyle PSCustomObject or $null
    Width     = 'Fill'          # 'Fill', 'Auto', integer (cols), or '50%'
    Height    = 'Auto'          # 'Fill', 'Auto', integer (rows)
}
```

### Component Node (nested TEA)

```powershell
[PSCustomObject]@{
    Type        = 'Component'   # string, required
    ComponentId = 'my-list'     # string, required — used for message routing
    SubModel    = $subModel     # PSCustomObject, required — component's own model
    ViewFn      = $viewFn       # scriptblock: param($SubModel) → ViewNode, required
}
```

---

## Style Object Schema

Created via `New-ElmStyle`. All params optional.

```powershell
[PSCustomObject]@{
    Foreground    = $null       # hex '#RRGGBB', 256-color int (0-255), or named string
    Background    = $null
    Bold          = $false
    Italic        = $false
    Underline     = $false
    Strikethrough = $false
    Border        = 'None'      # None, Normal, Rounded, Thick, Double
    PaddingTop    = 0
    PaddingRight  = 0
    PaddingBottom = 0
    PaddingLeft   = 0
    MarginTop     = 0
    MarginRight   = 0
    MarginBottom  = 0
    MarginLeft    = 0
    Align         = 'Left'      # Left, Center, Right
    Width         = $null       # overrides node Width: 'Fill', 'Auto', int, '50%'
    Height        = $null
}
```

**Padding/Margin shorthand** (CSS-style):
- `-Padding 1` → all four sides = 1
- `-Padding 1, 2` → top/bottom=1, left/right=2
- `-Padding 1, 2, 3, 4` → top=1, right=2, bottom=3, left=4

---

## Message Shape

Messages are PSCustomObjects with a `Type` string property. All other fields are app-defined.

```powershell
# User-defined
[PSCustomObject]@{ Type = 'Increment' }
[PSCustomObject]@{ Type = 'SetName'; Name = 'Alice' }

# Framework keyboard sub
[PSCustomObject]@{ Type = 'KeyPressed'; Key = 'UpArrow' }           # ConsoleKey name
[PSCustomObject]@{ Type = 'KeyPressed'; Key = 'c'; Modifiers = 'Control' }

# Framework timer sub
[PSCustomObject]@{ Type = 'Tick'; Timestamp = (Get-Date) }

# Framework component routing
[PSCustomObject]@{ Type = 'ComponentMsg'; ComponentId = 'search'; Msg = $innerMsg }
```

---

## Driver Abstraction Detail

The event loop NEVER calls `[Console]::Write` or touches a WebSocket directly. All I/O goes
through two `ConcurrentQueue[string]` instances created by the entry point and passed to both
the loop and the driver.

```powershell
$InputQueue  = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
$OutputQueue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
```

### Terminal Driver

Spawns two background runspaces:
1. **Input runspace** — polls `[Console]::KeyAvailable`; converts `ConsoleKeyInfo` to key
   message string; pushes to `$InputQueue`
2. **Output runspace** — dequeues from `$OutputQueue`; writes to `[Console]::Out`

### WebSocket Driver

1. **`Invoke-ElmWebSocketListener`** — `System.Net.HttpListener` WebSocket host:
   - `GET /` → serves embedded xterm.js HTML page
   - `GET /ws` → upgrades to WebSocket via `AcceptWebSocketAsync()`
   - Receive loop: WebSocket frame → UTF-8 decode → push to `$InputQueue`
   - Send loop: dequeue `$OutputQueue` → UTF-8 encode → WebSocket send
2. **`Get-ElmXtermPage`** — returns an HTML string (no file system required):
   - xterm.js from CDN
   - `const ws = new WebSocket('ws://localhost:{port}/ws')`
   - `terminal.onData(d => ws.send(d))` — keyboard → WebSocket
   - `ws.onmessage(e => terminal.write(e.data))` — ANSI output → xterm.js
   - Resize handler sends terminal dimensions to PS app on connect/resize

Both drivers return the same PSCustomObject shape:
```powershell
[PSCustomObject]@{
    Type        = 'Terminal'  # or 'WebSocket'
    InputQueue  = $InputQueue
    OutputQueue = $OutputQueue
    Runspaces   = @(...)
    Stop        = { param($Driver) $Driver.Runspaces | ForEach-Object { $_.Dispose() } }
}
```

---

## Canonical Input Format

All `$InputQueue` entries are plain strings in one of four canonical forms:

| Form | Example | Produced by |
|---|---|---|
| Printable char | `'a'`, `'Z'`, `'1'`, `' '` | Terminal: `ConsoleKeyInfo.KeyChar`; WebSocket: single printable byte from xterm.js |
| Special key | `'UpArrow'`, `'Enter'`, `'Backspace'`, `'F5'` | Terminal: `ConsoleKey` enum name; WebSocket: ANSI escape → lookup table |
| Modified key | `'ctrl+c'`, `'shift+UpArrow'`, `'alt+Enter'` | Terminal: `ConsoleKeyInfo.Modifiers` prefix; WebSocket: ANSI modifier codes |
| Resize event | `'Resize:80x24'` | Terminal: `[Console]::WindowWidth/Height` delta detected each cycle; WebSocket: `ESC[8;rows;cols]t` from xterm.js resize handler |

`ConvertFrom-ElmKeyString -Raw $str` parses a canonical string into a typed PSCustomObject:

```powershell
# Key event
[PSCustomObject]@{ Type = 'Key'; Key = 'UpArrow'; Modifiers = 'None' }
[PSCustomObject]@{ Type = 'Key'; Key = 'c';       Modifiers = 'Control' }

# Resize event
[PSCustomObject]@{ Type = 'Resize'; Width = 80; Height = 24 }
```

`Invoke-ElmSubscriptions` is the **sole consumer** of `$InputQueue`. The event loop never calls
`TryDequeue` directly.

---

## Module Structure

```
Elm/
├── Elm.psd1                                    # manifest: PS 5.1+, FunctionsToExport
├── Elm.psm1                                    # dot-sources all Public/**/*.ps1, Private/**/*.ps1
│
├── Public/
│   ├── Runtime/
│   │   ├── Start-ElmProgram.ps1                # Terminal entry point
│   │   └── Start-ElmWebServer.ps1              # Browser/WebSocket entry point
│   ├── Drivers/
│   │   ├── New-ElmTerminalDriver.ps1           # Creates terminal I/O driver
│   │   └── New-ElmWebSocketDriver.ps1          # Creates WebSocket I/O driver
│   ├── View/
│   │   ├── New-ElmText.ps1                     # Text view node factory
│   │   ├── New-ElmBox.ps1                      # Vertical box node factory
│   │   └── New-ElmRow.ps1                      # Horizontal row node factory (Box shorthand)
│   ├── Style/
│   │   └── New-ElmStyle.ps1                    # Style object factory
│   ├── Subscriptions/
│   │   ├── New-ElmKeySub.ps1                   # Keyboard subscription factory
│   │   └── New-ElmTimerSub.ps1                 # Timer subscription factory
│   └── Components/                             # Built-in widget library (Bubbles-inspired)
│       ├── New-ElmTextInput.ps1                # Single-line text input
│       ├── New-ElmList.ps1                     # Scrollable selectable list
│       ├── New-ElmSpinner.ps1                  # Animated spinner (tick-driven)
│       ├── New-ElmProgressBar.ps1              # Percent-fill progress bar
│       └── New-ElmViewport.ps1                 # Scrollable text viewport
│
└── Private/
    ├── Core/
    │   ├── Copy-ElmModel.ps1                   # Deep-copy PSCustomObject (JSON roundtrip)
    │   ├── Invoke-ElmUpdate.ps1                # deep-copy → call Update → validate return
    │   └── Invoke-ElmView.ps1                  # call View → validate tree shape
    ├── Rendering/
    │   ├── Enable-VirtualTerminal.ps1          # P/Invoke ENABLE_VIRTUAL_TERMINAL_PROCESSING
    │   ├── Measure-ElmViewTree.ps1             # Flexbox layout pass: assign X/Y/W/H to nodes
    │   ├── ConvertTo-AnsiOutput.ps1            # Walk measured tree → full-frame ANSI string
    │   ├── ConvertTo-AnsiPatch.ps1             # Apply patch list → incremental ANSI string
    │   └── Compare-ElmViewTree.ps1             # Diff old/new measured trees → patch list
    ├── Style/
    │   ├── Resolve-ElmColor.ps1                # Named/hex/256 → ANSI SGR escape sequence
    │   ├── ConvertTo-BorderChars.ps1           # Border style name → Unicode box-drawing chars
    │   └── Apply-ElmStyle.ps1                  # Wrap string with ANSI SGR + border/padding/margin
    ├── Drivers/
    │   └── Invoke-ElmDriverLoop.ps1            # Background runspace scaffolding helper
    ├── Web/
    │   ├── Invoke-ElmWebSocketListener.ps1     # HttpListener WebSocket host loop
    │   ├── Get-ElmXtermPage.ps1                # Return self-contained HTML with bundled xterm.js
    │   ├── xterm.min.js                        # Bundled xterm.js (pinned version, no CDN)
    │   └── xterm-addon-fit.min.js              # Bundled xterm-addon-fit (pinned version)
    ├── Subscriptions/
    │   └── Invoke-ElmSubscriptions.ps1         # Poll all subs, collect messages
    └── Runtime/
        └── Invoke-ElmEventLoop.ps1             # The main loop
```

---

## Implementation Phases

### Phase 1 — Foundation & Module Scaffold

**Goal:** Buildable, importable module skeleton with core utility functions all later phases depend on.

**Deliverables:**

- `Elm.psd1` — manifest: `RootModule = 'Elm.psm1'`, `PowerShellVersion = '5.1'`,
  `FunctionsToExport = @()` (populated as public functions are added)
- `Elm.psm1` — dot-sources `Public/**/*.ps1` and `Private/**/*.ps1` at import- All folder structure created
- `.gitignore` (`.vs/`, `*.user`, `TestResults/`, `*.pester.xml`)

- **`Enable-VirtualTerminal`**:
  - `Add-Type` with P/Invoke for `GetConsoleMode`, `SetConsoleMode`, `GetStdHandle`
  - Reads current stdout handle mode, ORs in `0x0004`, writes back
  - Returns `[bool]`: `$true` if flag was applied or already set; `$false` on failure
  - On PS7 Linux/macOS: returns `$true` immediately (already supported)
  - On failure: `Write-Warning`; does NOT throw (best-effort)

- **`Copy-ElmModel`**:
  - Input: any `PSCustomObject` (or hashtable)
  - Mechanism: `$Model | ConvertTo-Json -Depth 20 | ConvertFrom-Json`
  - **Depth limit:** `ConvertTo-Json -Depth 20` silently truncates objects nested deeper than 20
    levels in PS 5.1 (no error thrown). Document this as a framework constraint — deeply nested
    models will be silently corrupted on copy. If a developer hits this, they should flatten
    their model structure.
  - Returns new PSCustomObject with same shape; all nested objects are new references
  - Throws terminating error (`$PSCmdlet.ThrowTerminatingError`) if input is `$null`

**Tests to write first:**

`Enable-VirtualTerminal.Tests.ps1`:
- On non-Windows PS7: returns `$true`; no P/Invoke class instantiated
- On Windows with successful `SetConsoleMode`: returns `$true`
- On Windows with failed `SetConsoleMode`: returns `$false`; emits `Write-Warning`; does not throw

`Copy-ElmModel.Tests.ps1`:
- Flat PSCustomObject: returns equal-value but distinct-reference object
- Nested PSCustomObject: nested properties are also distinct references
- Array property: copy has independent array (mutating copy array doesn't affect original)
- `$null` input: throws terminating error
- Hashtable input: returns PSCustomObject equivalent

---

### Phase 2 — Style System (LipGloss-inspired)

**Goal:** A composable style object and the ANSI color/border rendering functions that apply it.

**Deliverables:**

- **`New-ElmStyle`**:
  - All params optional
  - `-Padding [int[]]` / `-Margin [int[]]`: 1, 2, or 4 values (CSS shorthand expansion)
  - `-Base [PSCustomObject]`: inherit from another style, override specific fields
  - Returns PSCustomObject with all style fields explicitly set (no `$null` ambiguity)

- **`Resolve-ElmColor`**:
  - Input: string (named, `'#RRGGBB'` hex, stringified int) or int (256-index)
  - Named set: the 16 standard ANSI constants (`Black`, `White`, `Red`, `Green`, `Blue`, `Yellow`, `Cyan`, `Magenta`, each with a `Bright` prefix variant)
  - **No downsampling.** Always emits the ANSI sequence matching the requested color type. PowerShell ISE is explicitly out of scope.
  - Hex: parse R/G/B → emit `ESC[38;2;R;G;Bm` (fg) or `ESC[48;2;R;G;Bm` (bg)
  - 256-index: emit `ESC[38;5;Nm` / `ESC[48;5;Nm`
  - Params: `-Color`, `-IsForeground [switch]` (default fg)
  - Invalid input: non-terminating error; returns empty string

- **`ConvertTo-BorderChars`**:
  - Input: border style name string
  - Returns PSCustomObject: `@{ TL; T; TR; L; R; BL; B; BR }` (Unicode box-drawing chars)
  - `None`: all empty strings
  - `Normal`:  `┌ ─ ┐ │ │ └ ─ ┘`
  - `Rounded`: `╭ ─ ╮ │ │ ╰ ─ ╯`
  - `Thick`:   `┏ ━ ┓ ┃ ┃ ┗ ━ ┛`
  - `Double`:  `╔ ═ ╗ ║ ║ ╚ ═ ╝`
  - Unknown style: non-terminating error; returns `None` chars

- **`Apply-ElmStyle`**:
  - Input: content string (already rendered), width int, style PSCustomObject
  - Steps: apply SGR sequences (bold/italic/underline/fg/bg), add padding (space chars),
    add border (box-drawing chars around padded block), add margin (surrounding spaces/newlines)
  - Returns the fully styled multi-line string block

**Tests to write first:**

`New-ElmStyle.Tests.ps1`:
- No params: all fields are `$false`/`0`/`'None'`/`'Left'`/`$null`
- `-Padding 2`: all four padding fields = 2
- `-Padding 1, 2`: top/bottom=1, left/right=2
- `-Padding 1, 2, 3, 4`: CSS order preserved
- `-Base + override`: base fields present; overridden field replaced

`Resolve-ElmColor.Tests.ps1`:
- Named `'Red'` fg → correct ANSI sequence
- Hex `'#FF0000'` fg → `ESC[38;2;255;0;0m`
- Hex `'#FF0000'` bg → `ESC[48;2;255;0;0m`
- Int `196` fg → `ESC[38;5;196m`
- Invalid string → non-terminating error; empty string returned

`ConvertTo-BorderChars.Tests.ps1`:
- Each of the 5 style names → correct char set
- Unknown name → non-terminating error; None chars returned

`Apply-ElmStyle.Tests.ps1`:
- No style (null): content returned unchanged
- Bold: content wrapped in `ESC[1m`...`ESC[0m`
- PaddingLeft=2: two spaces prepended to each content line
- Border `Rounded`: correct box-drawing chars wrap the content
- Combined bold + padding + border: correct combined output

---

### Phase 3 — View DSL & Flexbox Layout

**Goal:** Factory functions for view tree nodes and a two-pass layout engine that assigns
screen coordinates to every node.

**Deliverables:**

- **`New-ElmText`**: params `-Content [string]` (mandatory), `-Style`; returns Text node
- **`New-ElmBox`**: params `-Children [object[]]` (mandatory), `-Style`, `-Width`, `-Height`; returns Box Vertical node (`Direction = 'Vertical'`)
- **`New-ElmRow`**: params `-Children [object[]]` (mandatory), `-Style`, `-Width`, `-Height`; returns Box Horizontal node (`Direction = 'Horizontal'`). Neither function accepts a `-Direction` parameter — direction is encoded in the function name.

- **`Measure-ElmViewTree`**:
  - Input: root view node, available `$TermWidth` (int), `$TermHeight` (int)
  - **Pass 1 (bottom-up)** — compute natural sizes for `Auto` nodes:
    - Text: `NaturalWidth = Content.Length + PaddingLeft + PaddingRight + (border ? 2 : 0)`
    - Box Vertical: `NaturalWidth = max(children NaturalWidth)`; `NaturalHeight = sum(children NaturalHeight) + padding`
    - Box Horizontal: `NaturalWidth = sum(children NaturalWidth) + padding`; `NaturalHeight = max(children NaturalHeight)`
    - Skip `Fill` children in this pass
  - **Pass 2 (top-down)** — assign `X`, `Y`, `Width`, `Height`:
    - Root gets terminal dimensions
    - Fixed children: get their natural size
    - `Fill` children: divide remaining space equally; the last `Fill` child receives any remainder columns/rows from integer division
    - `%` widths: `[int][Math]::Floor($ParentWidth * $Pct / 100)`
    - Track running cursor X/Y as children are placed
  - Returns new tree (PSCustomObject per node with added `X`, `Y`, `Width`, `Height` fields)

- **`ConvertTo-AnsiOutput`**:
  - Input: measured view tree root (`-Root`)
  - Emits `ESC[?25l` (hide cursor), `ESC[2J` (clear screen)
  - Walks tree; for each leaf Text node: emit `ESC[{Y+1};{X+1}H` + `Apply-ElmStyle` output
  - Emits `ESC[?25h` (show cursor) at end
  - Returns single ANSI string
  - Called when `$PrevTree -eq $null` (first render) or after any `FullRedraw` patch

- **`ConvertTo-AnsiPatch`**:
  - Input: patch list from `Compare-ElmViewTree` (`-Patches [object[]]`)
  - For each `Replace` patch: emits `ESC[{Y+1};{X+1}H` + `Apply-ElmStyle` output
  - For each `Clear` patch: emits `ESC[{Y+1};{X+1}H` + spaces spanning the cleared region
  - `FullRedraw` patches: ignored (caller switches to `ConvertTo-AnsiOutput` instead)
  - Returns single ANSI string

**Tests to write first:**

`New-ElmText.Tests.ps1`, `New-ElmBox.Tests.ps1`, `New-ElmRow.Tests.ps1`:
- Return correct `Type` values
- `Style` defaults to `$null`; `Width`/`Height` default to `'Auto'`
- `New-ElmRow` returns `Direction = 'Horizontal'`
- `$null` mandatory param: terminating error

`Measure-ElmViewTree.Tests.ps1`:
- Single text `'hello'` in 80-col terminal: Width=5, X=0, Y=0
- Two text nodes in Vertical box: second node Y=1
- `Fill` child in 80-col terminal with no siblings: Width=80
- Two `Fill` children horizontally: each Width=40
- `'50%'` width in 80-col parent: Width=40
- Nested boxes: inner nodes have correct absolute X, Y
- Text with PaddingLeft=2: Width = Content.Length + 2

`ConvertTo-AnsiOutput.Tests.ps1`:
- Single text node at 0,0: output contains `ESC[1;1H` and content string
- Text with style: output contains SGR sequence
- Two nodes at different positions: both cursor-position sequences present

`ConvertTo-AnsiPatch.Tests.ps1`:
- `Replace` patch: output contains correct cursor-position sequence and new content
- `Clear` patch: output contains spaces spanning the cleared region at correct position
- Empty patch list: returns empty string
- `FullRedraw` patch in list: skipped (not emitted)

---

### Phase 4 — Diff Engine

**Goal:** Compare two measured view trees and produce the minimal ANSI patch set to transform
the previous frame into the new one — avoiding full clear+redraw every cycle.

**Deliverables:**

- **`Compare-ElmViewTree`**:
  - Input: `$OldTree` (previous measured frame), `$NewTree` (new measured frame)
  - Walk both trees in lockstep
  - Patch types:
    ```powershell
    [PSCustomObject]@{ Type = 'Replace'; X = 10; Y = 3; Content = 'new'; Style = $style }
    [PSCustomObject]@{ Type = 'Clear';   X = 5;  Y = 2; Width = 20; Height = 1 }
    [PSCustomObject]@{ Type = 'FullRedraw' }
    ```
  - If any node's `X`, `Y`, `Width`, or `Height` changed → emit `FullRedraw` (layout change)
  - If only content or style changed at a position → emit `Replace` for that node
  - If node removed → emit `Clear` for its region
  - `FullRedraw` causes caller to skip patching and use `ConvertTo-AnsiOutput` for full frame

**Tests to write first:**

- Identical trees → empty patch list
- Text content changed, same position → single `Replace` with correct X/Y and new content
- Text style changed (fg color only) → `Replace` with updated style
- Node added to end of children → `Replace` for new node
- Node removed → `Clear` for its region
- Node width changed (layout change) → `FullRedraw`
- Nested tree: inner node content change → only inner node patched

---

### Phase 5 — Core Runtime & Driver Abstraction

**Goal:** The event loop and the two concrete drivers (terminal, WebSocket) that feed it.

**Deliverables:**

- **`Invoke-ElmUpdate`**:
  - `Copy-ElmModel($Model)` → `& $UpdateFn $Msg $Copy`
  - Validates return is PSCustomObject; if not → non-terminating error; return original model
  - Propagates exceptions as terminating errors

- **`Invoke-ElmView`**:
  - `& $ViewFn $Model`
  - Validates return has `Type` property; if not → terminating error

- **`Invoke-ElmDriverLoop`** (shared helper):
  - Creates a background runspace with `InitialSessionState`
  - **Module loading strategy (try/fallback)**:
    1. Attempts `$ISS.ImportPSModule($ModulePath)` where `$ModulePath` defaults to the module's own `$PSScriptRoot`
    2. On failure: injects minimum required functions (`ConvertFrom-ElmKeyString`, etc.) as serialized scriptblock parameters on the `PowerShell` instance; emits `Write-Warning` indicating fallback mode
  - Accepts `-ModulePath [string]` parameter for explicit override
  - Returns runspace handle for later disposal

- **`New-ElmTerminalDriver`** (Public):
  - Creates `$InputQueue`, `$OutputQueue`
  - **Input runspace**: `while ($true) { if ([Console]::KeyAvailable) { push to InputQueue } }`
  - **Output runspace**: `while ($true) { if (OutputQueue.TryDequeue()) { [Console]::Out.Write() } }`
  - Returns driver PSCustomObject

- **`Invoke-ElmEventLoop`**:
  - Params: `-InitFn`, `-UpdateFn`, `-ViewFn`, `-SubscriptionsFn`, `-Driver`
  - Never touches console or WebSocket directly
  - Loop (pseudo-code):
    ```
    $W        = [Console]::WindowWidth
    $H        = [Console]::WindowHeight
    $SubCache = @{}
    $Model    = & $InitFn
    $PrevTree = $null
    $Running  = $true
    while ($Running) {
        $Tree     = Invoke-ElmView -ViewFn $ViewFn -Model $Model
        $Measured = Measure-ElmViewTree -Root $Tree -Width $W -Height $H
        if ($null -eq $PrevTree) {
            $Output = ConvertTo-AnsiOutput -Root $Measured
        } else {
            $Patches = Compare-ElmViewTree -OldTree $PrevTree -NewTree $Measured
            if ($Patches | Where-Object { $_.Type -eq 'FullRedraw' }) {
                $Output = ConvertTo-AnsiOutput -Root $Measured
            } else {
                $Output = ConvertTo-AnsiPatch -Patches $Patches
            }
        }
        $Driver.OutputQueue.Enqueue($Output)
        $PrevTree = $Measured

        $SubMsgs = Invoke-ElmSubscriptions `
            -SubscriptionsFn $SubscriptionsFn `
            -Model           $Model `
            -InputQueue      $Driver.InputQueue `
            -SubCache        $SubCache
        foreach ($SubMsg in $SubMsgs) {
            switch ($SubMsg.Type) {
                'Resize' {
                    $W = $SubMsg.Width; $H = $SubMsg.Height
                    $PrevTree = $null   # force full redraw next cycle
                }
                'Quit'  { $Running = $false }
                default { $Model = Invoke-ElmUpdate -UpdateFn $UpdateFn -Msg $SubMsg -Model $Model }
            }
        }
        Start-Sleep -Milliseconds 16   # ~60fps cap
    }
    # finally block always runs — restores terminal state on Quit, Ctrl+C, or any unhandled exception
    ```

- **`Start-ElmProgram`** (Public):
  - Params: `-Init`, `-Update`, `-View`, `-Subscriptions` (optional, default `{ @() }`)
  - Calls `Enable-VirtualTerminal`, `New-ElmTerminalDriver`, `Invoke-ElmEventLoop`
  - On exit: `$Driver.Stop.Invoke($Driver)`, reset terminal (show cursor, `ESC[0m`)

**Tests to write first:**

`Invoke-ElmUpdate.Tests.ps1`:
- Returns new model from Update fn
- Original model not mutated (deep copy verified)
- Update fn returning `$null` → non-terminating error; original model returned
- Update fn throwing → terminating error propagated

`Invoke-ElmView.Tests.ps1`:
- Returns valid view tree
- `$null` return → terminating error
- Return without `Type` property → terminating error

`Invoke-ElmEventLoop.Tests.ps1`:
- `$W`/`$H` initialized from `[Console]::WindowWidth/Height` before first cycle
- Init called exactly once
- View called on each iteration (mock, count calls)
- First cycle: `ConvertTo-AnsiOutput` used (`$PrevTree` is `$null`)
- Subsequent cycle with no layout change: `ConvertTo-AnsiPatch` used
- `Resize` message → `$W`/`$H` updated; `$PrevTree` cleared; next cycle uses `ConvertTo-AnsiOutput`
- `Quit` message from subscription → loop exits; driver Stop called
- OutputQueue receives rendered ANSI string after each cycle

---

### Phase 6 — Subscriptions

**Goal:** A declarative subscription system letting the developer declare event sources as a
pure function of the model.

**Deliverables:**

- **`New-ElmKeySub`** (Public):
  - Params: `-OnKey [scriptblock]` — receives `$Key` string (ConsoleKey name), returns Msg or `$null`
  - Returns: `@{ Type = 'Key'; OnKey = $scriptblock }`

- **`New-ElmTimerSub`** (Public):
  - Params: `-IntervalMs [int]`, `-OnTick [scriptblock]` — receives `[datetime]`, returns Msg
  - Returns: `@{ Type = 'Timer'; IntervalMs = $n; LastFired = $null; OnTick = $scriptblock }`

- **`Invoke-ElmSubscriptions`** (Private):
  - Params: `-SubscriptionsFn`, `-Model`, `-InputQueue`, `-SubCache [hashtable]`
  - Calls `& $SubscriptionsFn $Model` to get current sub list (can change per model state)
  - Sole consumer of `$InputQueue`: drains queue with `TryDequeue` loop; passes each canonical key string through all registered `OnKey` callbacks; collects non-null messages
  - Resize strings (`'Resize:WxH'`) recognized and returned as `[PSCustomObject]@{ Type = 'Resize'; Width = $W; Height = $H }`
  - Timer subs: looks up `$LastFired` from `$SubCache` (key: `"Timer:$($Sub.IntervalMs)"`); fires `-OnTick` if elapsed ≥ `IntervalMs`; writes updated timestamp back to `$SubCache`
  - Returns array of Msg PSCustomObjects

**Tests to write first:**

`New-ElmKeySub.Tests.ps1` / `New-ElmTimerSub.Tests.ps1`:
- Correct PSCustomObject shape returned

`Invoke-ElmSubscriptions.Tests.ps1`:
- Key in InputQueue → OnKey called → message in result
- OnKey returning `$null` → no message in result
- Multiple keys in InputQueue → all drained; each passed to OnKey callbacks
- Resize string in InputQueue → `Resize` message in result; no OnKey callbacks called
- Timer elapsed ≥ interval → OnTick called → Tick message in result
- Timer elapsed < interval → no message
- `$SubCache` updated with new `LastFired` timestamp after timer fires
- `$SubCache` not updated if timer did not fire
- Empty subscription list → empty result; queue still drained

---

### Phase 7 — Web App Support

**Goal:** Serve any PS Elm app in a browser via WebSocket + xterm.js with no changes to
application code. Mirrors Textual's `textual-serve` approach.

**How it works:**
1. Developer calls `Start-ElmWebServer` instead of `Start-ElmProgram`
2. An `HttpListener` serves the xterm.js HTML page at `GET /`
3. The browser loads xterm.js, opens a WebSocket to `ws://localhost:{port}/ws`
4. xterm.js translates keypresses → ANSI sequences → WebSocket → `$InputQueue`
5. `$OutputQueue` → WebSocket → xterm.js renders ANSI output
6. The MVU event loop runs identically — it only sees queues

**Deliverables:**

- **`Get-ElmXtermPage`** (Private):
  - Params: `-Port [int]`, `-Title [string]`
  - Returns a self-contained HTML string — no external files, no CDN, no internet required
  - **Bundles xterm.js and xterm-addon-fit inline** as minified JavaScript strings embedded in
    the PowerShell module (stored in `Private/Web/xterm.min.js` and `Private/Web/xterm-addon-fit.min.js`,
    read at module load time and interpolated into the HTML). The app works fully air-gapped.
  - Pin the bundled xterm.js version in the module manifest notes; update deliberately on new releases
  - Resize handler: sends `ESC[8;{rows};{cols}t` (terminal resize sequence) on connect and `window.onresize`

- **`Invoke-ElmWebSocketListener`** (Private):
  - Params: `-Port [int]`, `-InputQueue`, `-OutputQueue`
  - `[System.Net.HttpListener]` on `http://localhost:{port}/`
  - `GET /` → 200 with `Get-ElmXtermPage` HTML (always served regardless of connection state)
  - `GET /ws` → if no active connection: `AcceptWebSocketAsync('elm-tui')`; if connection active: `409 Conflict` with body `"A session is already active. Close the existing tab and refresh."`
  - Disconnection resets connection state, allowing reconnect
  - Runs receive/send loops in background runspace

- **`New-ElmWebSocketDriver`** (Public):
  - Params: `-Port [int]`
  - Creates queues, calls `Invoke-ElmWebSocketListener`, returns driver PSCustomObject

- **`Start-ElmWebServer`** (Public):
  - Same params as `Start-ElmProgram` plus `-Port [int]` (default 8080)
  - Creates WebSocket driver
  - Opens browser: `Start-Process http://localhost:{port}` (works on Windows/macOS/Linux)
  - Calls `Invoke-ElmEventLoop` with driver

**Tests to write first:**

`Get-ElmXtermPage.Tests.ps1`:
- Returns non-empty string
- Contains `WebSocket` constructor with correct port
- Contains xterm.js `<script>` tag
- `-Title` value appears in `<title>` tag

`Invoke-ElmWebSocketListener.Tests.ps1`:
- Mock HttpListener: incoming frame → pushed to InputQueue
- OutputQueue item → WebSocket send called (mock WebSocket)
- Starts without error on available port

`New-ElmWebSocketDriver.Tests.ps1`:
- Returns driver PSCustomObject with `InputQueue`, `OutputQueue`, `Stop` scriptblock

`Start-ElmWebServer.Tests.ps1`:
- Creates WebSocket driver (mock `New-ElmWebSocketDriver`)
- Passes correct driver to event loop (mock `Invoke-ElmEventLoop`)
- Calls `Start-Process` with correct URL (mock `Start-Process`)

---

### Phase 8 — Component Model (Bubbles-inspired)

**Goal:** Reusable, composable UI components with their own internal state, update logic, and
view — nested TEA programs embedded in a parent program.

**Pattern:**
```powershell
# A component is a PSCustomObject with three scriptblocks
$SearchBox = [PSCustomObject]@{
    Init   = { [PSCustomObject]@{ Value = ''; CursorPos = 0 } }
    Update = {
        param([Parameter(Mandatory)] $Msg, [Parameter(Mandatory)] $Model)
        switch ($Msg.Type) {
            'CharInput' {
                [PSCustomObject]@{
                    Value     = $Model.Value + $Msg.Char
                    CursorPos = $Model.CursorPos + 1
                }
            }
            default { $Model }
        }
    }
    View   = {
        param([Parameter(Mandatory)] $Model)
        New-ElmText -Content "$($Model.Value)_"
    }
}

# Parent Init embeds component's model
$Init = {
    [PSCustomObject]@{
        SearchModel = & $SearchBox.Init
        Results     = @()
    }
}

# Parent Update routes ComponentMsg to component's Update
$Update = {
    param([Parameter(Mandatory)] $Msg, [Parameter(Mandatory)] $Model)
    switch ($Msg.Type) {
        'ComponentMsg' {
            if ($Msg.ComponentId -eq 'search') {
                $NewSearch = & $SearchBox.Update $Msg.Msg $Model.SearchModel
                [PSCustomObject]@{ SearchModel = $NewSearch; Results = $Model.Results }
            } else { $Model }
        }
        default { $Model }
    }
}

# Parent View embeds component via New-ElmComponent
$View = {
    param([Parameter(Mandatory)] $Model)
    New-ElmBox -Children @(
        New-ElmComponent -ComponentId 'search' -Model $Model.SearchModel -ViewFn $SearchBox.View
        New-ElmBox -Children ($Model.Results | ForEach-Object { New-ElmText $_ })
    )
}
```

**Deliverables:**
- `New-ElmComponent` (Public — required by View functions; see ADR-011)
- `New-ElmComponentMsg -ComponentId $id -Msg $innerMsg` (Public helper) — creates wrapper message
- `Measure-ElmViewTree` expanded to handle `Component` nodes: calls `& $Node.ViewFn $Node.SubModel`, recursively measures the resulting subtree, replaces the Component node in the measured output — `ConvertTo-AnsiOutput` and `Compare-ElmViewTree` never see raw Component nodes

**Tests to write first:**
- Component Init returns valid model
- Component Update returns new model on matching message; returns unchanged model on unknown message
- Component View returns valid view tree node
- `New-ElmComponent` returns node with correct `Type`, `ComponentId`, `SubModel`, `ViewFn`
- `New-ElmComponentMsg` wraps message correctly
- Component node in view tree: `ConvertTo-AnsiOutput` calls ViewFn and produces ANSI output
- Nested components: grandchild component renders correctly

---

### Phase 9 — Built-in Widget Library ✓ COMPLETE

**Goal:** Pure view-function widgets (stateless renderers). Caller owns all state in their model;
widgets just render. Each widget returns a view-tree node. `New-ElmCharSub` added to the
subscription system to support printable-char input in text fields.

**Design note:** Implemented as pure view functions rather than full Init/Update/View component
triples. This is simpler, composable with any model shape, and consistent with the existing
`New-ElmText` / `New-ElmBox` API surface. Full component-model widgets remain a future option.

#### `New-ElmTextInput` ✓
- **Params**: `-Value`, `-CursorPos` (clamped), `-Focused` [switch], `-Placeholder`,
  `-CursorChar` (default `|`), `-Style`, `-FocusedStyle`
- **Returns**: `Text` node; renders `$before + $CursorChar + $after` when focused;
  placeholder when empty and unfocused

#### `New-ElmList` ✓
- **Params**: `-Items [string[]]`, `-SelectedIndex`, `-MaxVisible` (default 10),
  `-Prefix` (default `> `), `-UnselectedPrefix` (default `  `), `-Style`, `-SelectedStyle`
- **Returns**: `Box` node with auto-scrolling window of `Text` children

#### `New-ElmSpinner` ✓
- **Params**: `-Frame`, `-Variant` (`Dots`|`Braille`|`Bounce`|`Arrow`), `-Frames` (custom override), `-Style`
- **Returns**: `Text` node; `$char = $frameSet[$Frame % $frameSet.Count]`
- **Requires**: caller drives frame counter (e.g. from `New-ElmTimerSub` Tick messages)

#### `New-ElmProgressBar` ✓
- **Params**: `-Value` (0.0–1.0) or `-Percent` (0–100); `-Width` (default 20, min 4);
  `-FilledChar` (default `#`), `-EmptyChar` (default `-`), `-Style`
- **Returns**: `Text` node with `[####----]` format; ratio clamped to `[0, 1]`

#### `New-ElmViewport` ✓
- **Params**: `-Lines [string[]]` (`[AllowEmptyString()]`), `-ScrollOffset`, `-MaxVisible`, `-Style`
- **Returns**: `Box` node showing fixed-height window into `Lines`; `ScrollOffset` clamped

#### `New-ElmCharSub` ✓ (new subscription type)
- **Params**: `-Handler [scriptblock]`
- **Returns**: subscription object `@{ Type='Char'; Handler=... }`
- Fires for any printable ASCII char (0x20–0x7E) **not** already consumed by a `New-ElmKeySub`
  in the same subscription list; handler receives raw `KeyDown` event with `.Char` property

**`Invoke-ElmSubscriptions` updated** to collect `Char` subs and dispatch after key-sub matching;
pass-through mode suppressed when char subs are present.

**Deliverables:** 88 Pester tests across 5 test files (21 TextInput, 20 ProgressBar, 18 Spinner,
15 List, 13 Viewport). `Invoke-WidgetShowcaseDemo.ps1` demonstrates all five widgets with
live-adjustable config options and modal text input.

---

## Key Technical Notes

### P/Invoke for Virtual Terminal (Windows)
```powershell
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class ElmConsoleHelper {
    public const int  STD_OUTPUT_HANDLE                = -11;
    public const uint ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004;

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
}
'@
```

### Flexbox Layout Algorithm (simplified)
```
Pass 1 — bottom-up natural sizes (skip Fill children):
  Text:             NaturalW = Content.Length + padding + border
  Box Vertical:     NaturalW = max(children NaturalW); NaturalH = sum(children NaturalH)
  Box Horizontal:   NaturalW = sum(children NaturalW); NaturalH = max(children NaturalH)

Pass 2 — top-down assignment:
  Root = (TermWidth, TermHeight)
  For each box, track remaining space after fixed/auto children are placed
  Divide remaining space equally among Fill children
  Track running cursor X (horizontal) or Y (vertical) to assign node positions
```

### ANSI Reference
```
ESC[{row};{col}H    move cursor (1-indexed)
ESC[2J              clear screen
ESC[K               clear to end of line
ESC[?25l            hide cursor
ESC[?25h            show cursor
ESC[0m              reset all SGR
ESC[1m              bold
ESC[3m              italic
ESC[4m              underline
ESC[9m              strikethrough
ESC[38;2;R;G;Bm     truecolor foreground
ESC[48;2;R;G;Bm     truecolor background
ESC[38;5;Nm         256-color foreground
ESC[48;5;Nm         256-color background
```

---

## Out of Scope (Initial Release)

- **PowerShell ISE** — does not support ANSI escape sequences; not a supported host.
  It is 2026. Please use [Windows Terminal](https://aka.ms/terminal), VS Code, or any terminal
  that was built after the Obama administration.
- **`Cmd` (async side effects)** — In Elm, `Update` returns `(Model, Cmd)` where `Cmd` represents
  side effects (HTTP, random, time) the runtime executes and feeds back as messages. Implementing
  this correctly in PS 5.1 requires runspaces with synchronized result queues — substantial
  complexity. Deferred to a future milestone.
- **Ports (external interop)** — Elm's bidirectional named channels for JS interop. PS equivalent
  would be hooks for embedding the TUI in a larger script. Deferred.
- Mouse input subscriptions
- Module publishing / versioning

---

## Future: Async Commands

- **`Cmd` (async side effects)** — `Update` returns `(Model, Cmd[])`. Each `Cmd` is a scriptblock
  that runs in a runspace and posts a result message back to `$InputQueue` when done.
- **`Send-ElmUrl`** — opens URL in browser platform-agnostically (terminal: `Start-Process`;
  web: instructs xterm.js to open link via WebSocket protocol extension)
- **`Send-ElmFile`** — delivers file to user (terminal: write to disk + notify; web: stream as
  ephemeral single-use download URL — mirrors Textual's `deliver_binary` / `App.deliver_text`)
- Mouse input subscriptions (via `ENABLE_MOUSE_INPUT` + ANSI mouse tracking: `ESC[?1000h`)
- Port-like interop hooks (named channels for embedding TUI in larger PS scripts)
- PSGallery module publishing

---

## Future: Cloud Hosting

- **Azure Web PubSub driver** — `New-ElmAzureWebPubSubDriver` replaces `New-ElmWebSocketDriver`
  with a driver backed by Azure Web PubSub. The MVU event loop and all application code are
  unchanged — only the entry point differs. Requires Azure Durable Functions or a Premium plan
  host (no execution timeout) to keep the event loop alive.
- **`Start-ElmAzureFunction`** — entry point for hosting a PS Elm app as a cloud-served TUI
  accessible from any browser, with no self-hosted infrastructure.

---

## Conventions (per Jake's standards)

- TDD: every function gets tests BEFORE any implementation
- Pester v5, `*.Tests.ps1`, write all test output to a file then read (avoids VS Code hang)
- OTBS brace style, 4-space indent, no tabs
- `[switch]` not `[bool]`; no aliases in scripts; full cmdlet names only
- `$PSCmdlet.ThrowTerminatingError()` for terminating errors in advanced functions
- `$PSCmdlet.WriteError()` for non-terminating errors
- Comment-based help on all public functions (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`,
  `.EXAMPLE`, `.OUTPUTS`, `.NOTES`)
- CalVer versioning: `yyyy.M.dHHmm`
- No emojis in code or documentation (README excepted)
- Conventional commits: `type(scope): message` with max 5 bullet points
- NEVER run `git commit` or `git push` without Jake's explicit approval — always draft first
