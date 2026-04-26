# ADR-017 - Terminal Driver Uses `KeyAvailable` Polling Over Blocking `ReadKey`

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | Phase 5 (Runtime - `New-ElmTerminalDriver`) |

## Context

The terminal input reader runs in a dedicated background runspace and enqueues
`KeyDown` events into a `ConcurrentQueue`. Two strategies were evaluated for
reading keys:

**Blocking `ReadKey`**: Call `[Console]::ReadKey($true)` directly. The call blocks
until a key is pressed, then returns immediately. Zero idle CPU.

**`KeyAvailable` polling**: Check `[Console]::KeyAvailable` in a tight loop; call
`ReadKey` only when a key is buffered. Sleep briefly when no key is available.

The initial implementation used `KeyAvailable` polling with a 10ms idle sleep. This
was changed to blocking `ReadKey` to improve macOS Terminal.app responsiveness.
However, blocking `ReadKey` introduced a quit-reliability regression: the
`CancellationToken` check in the loop condition only fires *after* `ReadKey` returns,
so quitting requires a second keypress to unblock the reader. `PowerShell.Stop()` does
not reliably interrupt a native blocking `ReadKey` call on macOS/.NET.

## Decision

Use `KeyAvailable` polling with a **1ms idle sleep** (reduced from the original 10ms).

```powershell
while (-not $token.IsCancellationRequested) {
    try {
        if ([Console]::KeyAvailable) {
            $consoleKey = [Console]::ReadKey($true)
            $queue.Enqueue(...)
        } else {
            [System.Threading.Thread]::Sleep(1)
        }
    } catch {
        [System.Threading.Thread]::Sleep(50)
    }
}
```

## Rationale

- **Quit reliability**: cancellation is checked every 1ms when idle. The loop exits
  cleanly without requiring an extra keypress.
- **Input latency**: 1ms idle sleep is imperceptible. With the `Copy-ElmModel`
  reflection clone (ADR-016) reducing render cost, the overall system is fast enough
  that 1ms polling latency is not observable.
- **Simplicity**: no coordination between the reader runspace and the event loop is
  needed to handle quit.
- **macOS compat**: `KeyAvailable` is unreliable on macOS Terminal.app when renders
  are slow (it returns `$false` during active rendering). With fast renders (ADR-016)
  this is no longer a practical issue.

## Consequences

- Idle CPU is slightly higher than blocking `ReadKey` (1ms poll loop vs. pure block),
  but negligible in practice for an interactive TUI.
- If `Copy-ElmModel` performance regresses significantly (e.g., models with large
  nested structures), macOS `KeyAvailable` unreliability may resurface and require
  revisiting this decision.
