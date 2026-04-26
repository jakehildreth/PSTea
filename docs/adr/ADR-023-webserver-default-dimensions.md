# ADR-023 - Start-ElmWebServer Default Dimensions (No PTY)

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | Phase 7 (`Start-ElmWebServer`) |

## Context

`Start-ElmProgram` reads `[Console]::WindowWidth` and `[Console]::WindowHeight` to determine
terminal dimensions, validates that requested `-Width`/`-Height` do not exceed the actual
terminal size, and falls back to 80×24 if no TTY is detected.

`Start-ElmWebServer` runs without an attached PTY. In this context:
- `[Console]::WindowWidth` returns 0
- `[Console]::WindowHeight` returns 0
- The PTY-size validation in `Start-ElmProgram` would reject or fall back to 80×24

80 columns is too narrow for most TUI apps. xterm.js in a typical browser window comfortably
renders 200+ columns and 50+ rows with a normal font size.

Resize support is deferred (see ADR-024), so dimensions are fixed at the time of connection.

## Decision

**`Start-ElmWebServer` defaults to 220 columns × 50 rows and bypasses `Start-ElmProgram` entirely.**

- `-Width` defaults to 220 (can be overridden)
- `-Height` defaults to 50 (can be overridden)
- `Start-ElmWebServer` calls `Invoke-ElmEventLoop` directly, not via `Start-ElmProgram`
- No PTY dimension validation is performed
- xterm.js is initialized with the same dimensions on the browser side so the layout matches

The values 220×50 are chosen to fill a typical full-screen browser window at 14px font.
Users can override with `-Width`/`-Height` if their app has different requirements.

## Rationale

- **Bypassing Start-ElmProgram**: The PTY validation would throw a terminating error or
  silently fall back to 80×24 (too narrow). Direct invocation of `Invoke-ElmEventLoop` is
  the cleanest solution.
- **220×50 defaults**: Wide enough for side-by-side panel layouts; tall enough for list views.
  A TUI that looks good at 80×24 in a terminal will look proportionally better with more space.
- **No dynamic resize**: Implementing dynamic resize requires the event loop to accept a
  `Resize` message type and re-measure + re-render the entire view tree. That is a significant
  change. Fixed dimensions at connect is acceptable for v1.

## Future Work

ADR-024 defers resize. When resize is implemented, `Start-ElmWebServer` can set an initial
size and update via `Resize` canonical messages injected into the InputQueue by the WebSocket
receive runspace.
