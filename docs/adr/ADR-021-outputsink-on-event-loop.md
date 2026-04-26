# ADR-021 - OutputSink Scriptblock on Invoke-ElmEventLoop

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | Phase 7 (`Invoke-ElmEventLoop`, `New-ElmWebSocketDriver`, `Start-ElmWebServer`) |

## Context

The original Phase 7 plan described an `OutputQueue` (`ConcurrentQueue[string]`) that the event
loop would write to, with a driver reading and forwarding frames. This mirrors how the
`InputQueue` works for input.

However, the existing `Invoke-ElmEventLoop` writes directly to `[Console]::Write` at **four
render sites**:

1. Initial render (after first `Invoke-ElmView` call)
2. Full-redraw in the subscription path (`FullRedraw = $true`)
3. Patch output in the subscription path (incremental diff)
4. Legacy path output (when no `SubscriptionFn` is set)

Additionally, the `hideCursor` and `showCursor` ANSI sequences are written at entry and in the
`finally` block via `[Console]::Write`.

An `OutputQueue` approach would require the event loop to enqueue to a queue and block on
acknowledgement (or accept that frames may queue up). It also adds an object allocation per
frame and requires a drain runspace.

## Decision

**Add an optional `-OutputSink [scriptblock]` parameter to `Invoke-ElmEventLoop`.**

When `$OutputSink` is `$null` (the default), all writes use `[Console]::Write` exactly as
today — terminal behavior is unchanged.

When `$OutputSink` is set, every `[Console]::Write($ansiString)` call is replaced with:

```powershell
if ($null -ne $OutputSink) { & $OutputSink $ansiString } else { [Console]::Write($ansiString) }
```

This applies to all six write sites: hideCursor, initial render, FullRedraw, patch, legacy
path, and showCursor.

`Start-ElmProgram` passes `$null` (no change to existing callers).

`Start-ElmWebServer` passes a closure that enqueues to a `ConcurrentQueue[string]` drained by
the WebSocket send runspace in `Invoke-ElmWebSocketListener`.

## Rationale

- **Zero impact on terminal path**: default `$null` means no behavioral change.
- **No queue allocation for terminal use**: the OutputQueue only exists in the web path.
- **Synchronous in both paths**: `& $OutputSink` is a synchronous call; no new threading model.
- **Simpler than OutputQueue**: no drain runspace needed on the event loop side; the listener
  owns the send logic.
- **All write sites captured**: hideCursor/showCursor are also routed, so xterm.js receives
  cursor control codes it can handle correctly.

## Alternatives Considered

**OutputQueue on event loop**: Would require adding a `ConcurrentQueue[string]` param and
a drain mechanism. More consistent with the InputQueue pattern, but adds complexity and
allocation overhead for the terminal path that gains nothing from it.

**OutputSink on Start-ElmProgram only**: `Start-ElmProgram` could wrap the event loop, but
the OutputSink needs to be at the event loop level to capture all write sites including
hideCursor/showCursor.
