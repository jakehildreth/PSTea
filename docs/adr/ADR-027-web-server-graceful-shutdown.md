# ADR-027 - Web Server Graceful Shutdown and Port Release

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | Start-TeaWebServer, New-TeaWebSocketDriver, Invoke-TeaWebSocketListener |

## Context

When a web-driver PSTea application exits — whether via a `Quit` command from within the
UpdateFn, a Ctrl+C interrupt, or an unhandled exception — the `System.Net.HttpListener`
must release its port so the same port can be reused immediately for the next run.

Without explicit teardown, the HttpListener keeps the port bound until the OS process is
killed. This makes rapid iteration impossible: re-running the app on the same port fails
with a "port already in use" error.

Two exit paths require coverage:

1. **Quit message** — UpdateFn returns `[PSCustomObject]@{ Type = 'Quit' }`. The event
   loop breaks its `while` loop, returns normally, and the `finally` block in
   `Start-TeaWebServer` runs.

2. **Ctrl+C / exception** — PowerShell throws `PipelineStoppedException` (or another
   exception) into the event loop. `Invoke-TeaEventLoop`'s own `try/finally` runs
   (restores cursor), the exception propagates to `Start-TeaWebServer`'s `catch` block
   (which logs and re-throws), and then the `finally` block runs.

In both cases, PowerShell 7's `finally` semantics guarantee the cleanup block executes.
SIGKILL (`kill -9` / forced process termination) is explicitly out of scope; no platform
can reliably handle it.

## Decisions

### `finally` block is the authoritative cleanup path (S1)

`Start-TeaWebServer` initialises `$driver = $null` before entering the outer `try/finally`
block. Driver creation, tick-loop setup, `InitFn` invocation, and the event loop are all
inside that block, so the `finally` fires regardless of where an exception or Ctrl+C
interrupts execution. The null guard (`if ($null -ne $driver)`) prevents a no-op call when
the driver was never created (e.g. port probe threw before driver creation). No separate
SIGTERM handler is registered — PS7's `finally` semantics cover all practical exit paths
including `PipelineStoppedException` from Ctrl+C.

### `Stop()` + `Close()` for port release (S2)

In `Invoke-TeaWebSocketListener`'s Stop scriptblock the sequence is:
1. Set `$sharedState.Stop = $true` — signals the accept and send loops to exit cleanly.
2. Close the active WebSocket gracefully (with a 2-second timeout).
3. Stop and close both runspaces (`$acceptPs`, `$acceptRs`, `$sendPs`, `$sendRs`).
4. `$listener.Stop()` — stops accepting new connections.
5. `$listener.Close()` — releases all resources including the bound port.

Each call is individually wrapped in `try/catch {}` so a failure in one step does not
prevent subsequent steps from running. `HttpListener` does not expose an `Abort()` method
— `Close()` is the correct API for resource release on .NET.

### Accept loop exits via shared-state flag, not forced runspace abort (S3)

Setting `$sharedState.Stop = $true` signals the accept loop to exit at its next 200ms
poll. `$acceptPs.Stop()` is still called as a backstop, but the intent is for the loop to
exit gracefully via the flag before the forced stop takes effect. This avoids leaving the
`GetContextAsync` task in an undefined state.

## Consequences

- Port is released immediately after each run. Restarting on the same port works without
  a delay.
- `New-TeaWebSocketDriver` consumers must call `& $driver.Stop` (via the owning
  `Start-TeaWebServer` `finally` block) to release resources. Direct callers of
  `Invoke-TeaWebSocketListener` must call the returned `Stop` scriptblock.
- SIGKILL is out of scope. Users who force-kill the process must wait for the OS TCP
  TIME_WAIT to expire or use a different port.
- `HttpListener.Abort()` requires .NET 5+ (PS7+). This is already the minimum supported
  runtime for PSTea.
