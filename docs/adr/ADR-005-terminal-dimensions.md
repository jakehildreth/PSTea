# ADR-005 — Terminal Dimensions Initialization and Resize Handling

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | Phase 5 (Runtime), Phase 7 (WebSocket Driver) |

## Context

The event loop pseudo-code used `$W` and `$H` for terminal dimensions when calling
`Measure-ElmViewTree`, but never showed where they were initialized or updated on resize. The
layout engine requires accurate dimensions to resolve `Fill`, percentage widths, and absolute
node positions. Dimensions captured once at startup become stale if the user resizes the terminal.

## Options Considered

| Option | Description |
|--------|-------------|
| **Capture once; never update** | Simple but renders incorrectly after resize. |
| **Read `[Console]::WindowWidth/Height` every cycle** | Accurate but breaks driver abstraction — WebSocket driver has no console. |
| **Initialize from console; update via canonical `Resize` message** | Dimensions start from console (or WebSocket connect); resize events flow through `$InputQueue` as canonical strings; event loop updates and redraws. |

## Decision

**Initialize from console; update via canonical `Resize` message.**

- **Terminal driver:** `$W`/`$H` initialized from `[Console]::WindowWidth/Height` before the
  loop starts. The input runspace detects dimension changes each cycle and pushes `'Resize:WxH'`
  canonical strings to `$InputQueue`.
- **WebSocket driver:** xterm.js sends `ESC[8;rows;cols]t` on connect and on `window.onresize`.
  The driver translates these to `'Resize:WxH'` canonical strings.
- **Event loop:** `Resize` messages returned from `Invoke-ElmSubscriptions` update `$W`/`$H` and
  set `$PrevTree = $null` to force `ConvertTo-AnsiOutput` on the next cycle.

## Rationale

The driver abstraction requires that the event loop never call `[Console]::WindowWidth` directly,
as this would break under the WebSocket driver. Routing resize events through the canonical input
format (ADR-001) keeps the event loop driver-agnostic and handles both drivers identically.

## Consequences

- `ConvertFrom-ElmKeyString` must handle `'Resize:WxH'` strings in addition to key events.
- The event loop gains `$W`, `$H` initialization before the loop and `Resize` handling inside it.
- A full redraw is forced on every resize (layout changes require it).
- `Invoke-ElmEventLoop` tests can inject `Resize` messages to verify dimension update behavior.
