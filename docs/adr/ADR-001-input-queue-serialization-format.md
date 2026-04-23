# ADR-001 — Input Queue Serialization Format

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | Phase 5 (Runtime), Phase 7 (WebSocket Driver) |

## Context

The terminal driver reads a `ConsoleKeyInfo` struct from `[Console]::ReadKey()`. The WebSocket
driver receives raw ANSI escape sequences from xterm.js (e.g., `^[[A` for UpArrow). These are
different representations of the same logical events. Both drivers push strings into the shared
`$InputQueue`. Without a defined format, `ConvertFrom-ElmKeyString` cannot be written and the
event loop cannot process input.

## Options Considered

| Option | Description |
|--------|-------------|
| **A — Normalize at driver** | Each driver converts its raw input to a canonical string format before enqueuing. `ConvertFrom-ElmKeyString` deserializes the canonical format. |
| **B — Push PSCustomObjects** | Use `ConcurrentQueue[object]`. Drivers push already-formed Msg objects. No deserializer needed. |

## Decision

**Option A.** Each driver normalizes to a canonical string format before pushing to `$InputQueue`.

### Canonical Format

| Form | Example | Produced by |
|------|---------|-------------|
| Printable char | `'a'`, `'Z'`, `'1'`, `' '` | Terminal: `ConsoleKeyInfo.KeyChar`; WebSocket: single printable byte |
| Special key | `'UpArrow'`, `'Enter'`, `'Backspace'`, `'F5'` | Terminal: `ConsoleKey` enum name; WebSocket: ANSI escape lookup table |
| Modified key | `'ctrl+c'`, `'shift+UpArrow'`, `'alt+Enter'` | Terminal: `ConsoleKeyInfo.Modifiers` prefix; WebSocket: ANSI modifier codes |
| Resize event | `'Resize:80x24'` | Terminal: dimension delta detected by input runspace; WebSocket: `ESC[8;rows;cols]t` |

`ConvertFrom-ElmKeyString -Raw $str` parses a canonical string into a typed PSCustomObject:

```powershell
[PSCustomObject]@{ Type = 'Key';    Key = 'UpArrow'; Modifiers = 'None' }
[PSCustomObject]@{ Type = 'Key';    Key = 'c';       Modifiers = 'Control' }
[PSCustomObject]@{ Type = 'Resize'; Width = 80;      Height = 24 }
```

## Rationale

String queue contents are inspectable — they can be dumped, logged, and asserted in tests. Failures
isolate to small lookup tables in each driver, not deep in the event loop. PSCustomObjects in a
queue are opaque and harder to diagnose.

## Consequences

- A ANSI escape → canonical string lookup table must be defined in the WebSocket driver.
- `ConvertFrom-ElmKeyString` must handle three string types: key events, modified keys, and resize.
- The canonical format must be versioned if extended (e.g., mouse events in v2).
