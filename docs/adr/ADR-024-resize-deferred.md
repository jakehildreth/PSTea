# ADR-024 - Resize Support Deferred for Phase 7

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | Phase 7 (`Start-ElmWebServer`, `Invoke-ElmEventLoop`, `Invoke-ElmWebSocketListener`) |

## Context

The original Phase 7 plan described resize support: when the browser window is resized,
xterm.js (via `fitAddon.fit()`) sends `ESC[8;rows;colst` over the WebSocket. The listener
would parse this and inject a `{ Type='Resize', Width, Height }` message into the InputQueue.
The event loop would then re-measure and re-render at the new dimensions.

Implementing this requires:
1. `ConvertFrom-AnsiVtSequence` to parse the resize sequence (trivial)
2. `Invoke-ElmEventLoop` to handle a `Resize` message type — updating `$TerminalWidth` and
   `$TerminalHeight` and forcing a full redraw
3. `Start-ElmWebServer` to pass the resize message through to the event loop
4. `Invoke-ElmSubscriptions` to not drop `Resize` messages (it currently ignores unknown types)

Changes 2–4 touch the core event loop and would need their own tests. The event loop's
dimensions are currently set once at startup and never updated. Adding mutable dimension state
adds complexity to the render loop.

## Decision

**Resize is deferred to a future release. Phase 7 uses fixed dimensions set at startup.**

- `Start-ElmWebServer` defaults to 220×50 (see ADR-023)
- xterm.js `fitAddon.fit()` will emit a resize sequence on initial connect; the WebSocket
  receive runspace discards resize sequences silently (or can enqueue them; the event loop
  will ignore unknown message types)
- `window.addEventListener('resize', ...)` is not implemented in the HTML page for v1
- The HTML page sets `cols` and `rows` on the `Terminal` constructor to match the server-side
  dimensions, so the initial render is correctly sized

## Rationale

- **Scope control**: Phase 7 is already a large change (6 new files, 1 modified). Resize adds
  material complexity to the event loop, which has broad impact.
- **Acceptable for v1**: Most TUI apps that users will want to serve are designed for a fixed
  layout. The 220×50 default is generous enough for nearly all existing demos.
- **No user-visible regression**: The terminal path has never had dynamic resize support either.
  Users are familiar with fixed-dimension TUIs.

## Future Work

To implement resize:
1. Add `Resize` handling to `Invoke-ElmEventLoop`: detect `Type='Resize'` message from queue,
   update `$TerminalWidth`/`$TerminalHeight`, set `$FullRedraw = $true`
2. Update `Invoke-ElmSubscriptions` to forward `Resize` messages (not just `Tick`)
3. Update `Get-ElmXtermPage` to add `window.addEventListener('resize', sendResize)`
4. Tests for resize flow end-to-end
