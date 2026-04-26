# ADR-022 - WebSocket Driver Input Format: PSCustomObjects, Not Canonical Strings

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | Phase 7 (`ConvertFrom-AnsiVtSequence`, `Invoke-ElmWebSocketListener`) |
| Supersedes | ADR-001 (partially) |

## Context

ADR-001 specified that each driver normalizes raw input to "a canonical string format" before
enqueuing, so the queue contains plain strings like `"UpArrow"`, `"Ctrl+C"`, etc.

The actual implementation diverged from this decision during development. The terminal driver
(`New-ElmTerminalDriver.ps1`) enqueues `PSCustomObject` items:

```powershell
[PSCustomObject]@{
    Type      = 'KeyDown'
    Key       = [System.ConsoleKey]$consoleKey.Key
    Char      = $consoleKey.KeyChar
    Modifiers = $consoleKey.Modifiers
}
```

The subscription system (`Invoke-ElmSubscriptions`, `New-ElmKeySub`, `New-ElmCharSub`) and all
existing applications are built around this PSCustomObject shape. Reverting to canonical strings
would require rewriting the entire subscription layer and all demo apps.

The WebSocket driver receives raw VT sequences from xterm.js `onData` (e.g. `\x1b[A` for
UpArrow, `\x03` for Ctrl+C). These must be translated before enqueuing.

## Decision

**`ConvertFrom-AnsiVtSequence` translates raw VT strings from xterm.js into PSCustomObjects
matching the terminal driver's existing format.**

Each returned object has:
- `Type = 'KeyDown'`
- `Key = [System.ConsoleKey]` (e.g. `[ConsoleKey]::UpArrow`)
- `Char = [char]` (the Unicode character, or `[char]0` for non-printable)
- `Modifiers = [System.ConsoleModifiers]` (None, Ctrl, Alt, Shift, or combinations)

The function returns an **array** of objects because a single xterm.js `onData` callback can
contain multiple VT sequences (e.g. paste operations).

ADR-001's "canonical string" decision is superseded for the InputQueue format. The actual
canonical format is `PSCustomObject { Type, Key, Char, Modifiers }`.

## Rationale

- **Backward compatibility**: all existing subscription handlers, key matchers, and apps
  work without modification because they already receive PSCustomObjects.
- **Richer data**: PSCustomObjects carry the `Char` field (Unicode code point) that string
  representations would lose, enabling `New-ElmCharSub` and text input widgets to work on
  both terminal and web paths.
- **Single truth**: one format for both drivers; `Invoke-ElmSubscriptions` has no path
  divergence between terminal and web.

## VT Sequence Mapping

| VT Sequence     | ConsoleKey         | Modifiers |
|-----------------|--------------------|-----------|
| `\x1b[A`        | UpArrow            | None      |
| `\x1b[B`        | DownArrow          | None      |
| `\x1b[C`        | RightArrow         | None      |
| `\x1b[D`        | LeftArrow          | None      |
| `\x1b[H`        | Home               | None      |
| `\x1b[F`        | End                | None      |
| `\x1b[5~`       | PageUp             | None      |
| `\x1b[6~`       | PageDown           | None      |
| `\x1b[1;5A`     | UpArrow            | Ctrl      |
| `\x1b[1;5B`     | DownArrow          | Ctrl      |
| `\x1b[1;5C`     | RightArrow         | Ctrl      |
| `\x1b[1;5D`     | LeftArrow          | Ctrl      |
| `\x1b`          | Escape             | None      |
| `\x7f`          | Backspace          | None      |
| `\r`            | Enter              | None      |
| `\t`            | Tab                | None      |
| `\x01`–`\x1a`   | A–Z                | Ctrl      |
| Printable char  | A–Z, D0–D9, etc.   | None/Shift|
