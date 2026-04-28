# ADR-027 - Web Server Graceful Shutdown and Port Release

| Field    | Value |
|----------|-------|
| Status   | Accepted (revised) |
| Affects  | Start-TeaWebServer, New-TeaWebSocketDriver, Invoke-TeaWebSocketListener, PSTea.psm1 |

## Context

When a web-driver PSTea application exits — whether via a `Quit` command from within the
UpdateFn, a Ctrl+C interrupt, or an unhandled exception — the `System.Net.HttpListener`
must release its port so the same port can be reused immediately for the next run.

Without explicit teardown, the HttpListener keeps the port bound until the OS process is
killed. This makes rapid iteration impossible: re-running the app on the same port fails
with a "port already in use" error.

Three exit paths require coverage:

1. **Quit message** — UpdateFn returns `[PSCustomObject]@{ Type = 'Quit' }`. The event
   loop breaks its `while` loop, returns normally, and the `finally` block in
   `Start-TeaWebServer` runs.

2. **Ctrl+C in a normal terminal** — PowerShell throws `PipelineStoppedException` into
   the event loop. `Invoke-TeaEventLoop`'s own `try/finally` runs (restores cursor), the
   exception propagates to `Start-TeaWebServer`'s `catch` block (which logs and
   re-throws), and then the `finally` block runs.

3. **Ctrl+C in the VS Code Extension terminal** — The Extension kills the foreground
   runspace immediately without executing `finally` blocks or PowerShell-level cleanup.
   PS closures that reference the killed runspace's scope become invalid (see S3). Pure
   .NET objects stored before the runspace dies are the only reliable cleanup handle.

SIGKILL (`kill -9` / forced process termination) is explicitly out of scope; no platform
can reliably handle it. Module reimport with `-Force` is treated the same as a fresh
import and does not affect process-level state (see S4).

## Decisions

### `finally` block is the authoritative cleanup path for normal exits (S1)

`Start-TeaWebServer` initialises `$driver = $null` before entering the outer `try/finally`
block. Driver creation, tick-loop setup, `InitFn` invocation, and the event loop are all
inside that block, so the `finally` fires regardless of where an exception or Ctrl+C
interrupts execution. The null guard (`if ($null -ne $driver)`) prevents a no-op call when
the driver was never created (e.g. port probe threw before driver creation). `& $driver.Stop`
is wrapped in `try/catch {}` so any error from the closure is silently swallowed and does
not prevent the remaining cleanup steps.

### Shutdown sequence: CTS cancel → WS abort → listener close → BeginStop (S2)

In `Invoke-TeaWebSocketListener`'s Stop scriptblock the sequence is:

1. `$sharedState.Cts.Cancel()` — cancels the `CancellationToken` passed to `ReceiveAsync`
   and `SendAsync`, causing both tasks to fault immediately. This is required because
   `Task.Wait()` on a `ReceiveAsync(CancellationToken.None)` call blocks forever, keeping
   `PowerShell.Stop()` (which is synchronous) from ever returning, which in turn keeps
   `listener.Close()` from ever being reached.
2. `$sharedState.Stop = $true` — signals the accept and send `while` loops to exit.
3. `$ws.Abort()` — tears down the active WebSocket with a TCP RST, instantly. Using
   `CloseAsync().Wait()` would block waiting for a close handshake; `Abort()` is instant.
4. `$listener.Stop()` then `$listener.Close()` — stops accepting new connections and
   releases the bound port. This **must** happen before any runspace teardown (step 5),
   because `PowerShell.Stop()` is synchronous and will not return until the pipeline exits.
   If the pipeline is blocked on `Task.Wait()`, `Stop()` blocks indefinitely and
   `listener.Close()` is never reached.
5. `[void]$acceptPs.BeginStop($null, $null)` and `[void]$sendPs.BeginStop($null, $null)` —
   requests pipeline stop asynchronously (fire-and-forget). `BeginStop` returns immediately;
   the runspaces exit naturally via the Stop flag, closed listener, and CTS cancellation.
   Synchronous `Stop()` is not used here for the reason above.

Each call is individually wrapped in `try/catch {}` so a failure in one step does not
prevent subsequent steps from running.

### AppDomain named slots for cross-runspace and cross-reimport safety (S3)

PowerShell closures created with `GetNewClosure()` capture a reference to the originating
runspace's scope. When the VS Code Extension kills the foreground runspace via Ctrl+C, those
closures become invalid — calling them throws silently inside `catch {}`, leaving the port
bound.

To survive both runspace disposal and module reimport with `-Force`, the raw .NET objects
required for cleanup are stored in `[System.AppDomain]::CurrentDomain` named data slots
immediately after the listener starts:

| Slot key | Value | Purpose |
|---|---|---|
| `PSTea.ActiveListener` | `System.Net.HttpListener` | `Stop()` + `Close()` to release port |
| `PSTea.ActiveCts` | `CancellationTokenSource` | `Cancel()` to unblock `ReceiveAsync` |
| `PSTea.ActiveSharedState` | `Synchronized([hashtable])` | Set `Stop=$true`, get `ActiveSocket` |
| `PSTea.ActiveRunspaces` | `Runspace[]` | `Dispose()` after listener is closed |
| `PSTea.DriverContainer` | `Synchronized([hashtable])` with `.Active` | Module-level `OnRemove` hook |

`AppDomain` data is process-level: it survives module reimport (which resets `$script:`
variables), runspace disposal, and host restarts within the same process.

On each call to `Start-TeaWebServer`, the entry cleanup block reads all four `PSTea.Active*`
slots and performs the same CTS → WS → listener → runspace sequence before starting a new
run. This ensures a previously orphaned listener (e.g. from a VS Code Extension kill) is
released before the port probe runs.

### `$logFile` local capture for `GetNewClosure()` closures (S4)

`$script:TeaWebDebugLog` is set at dot-source time in `Write-TeaWebDebug.ps1`. A closure
created with `GetNewClosure()` resolves `$script:` at **execution time** via dynamic scope
lookup. If the originating runspace is disposed or the module is reimported, that lookup
returns `$null`, causing `Add-Content -Path $null` to throw a `ParameterBindingException`
that `-ErrorAction SilentlyContinue` cannot suppress (mandatory parameter binding errors
are not governed by `ErrorAction`).

Fix: capture `$logFile = $script:TeaWebDebugLog` as a plain local variable before the
closure is defined. `GetNewClosure()` closes over the local `$logFile` value directly,
avoiding the dynamic scope lookup entirely.

### Module `OnRemove` cleanup (S5)

`PSTea.psm1` registers an `$ExecutionContext.Module.OnRemove` handler that reads
`PSTea.DriverContainer` from the AppDomain and calls `& $c.Active.Stop` if a driver is
active. This fires when the module is removed (`Remove-Module PSTea`) but not on reimport
with `-Force` (the old module is removed before the new one loads). A null guard on
`$ExecutionContext.Module` is required because this property is `$null` in some host
contexts (e.g. when dot-sourcing outside a module).

## Consequences

- Port is released immediately after each run in all exit paths except SIGKILL.
- Restarting on the same port works without a delay, including from the VS Code Extension
  terminal after Ctrl+C.
- The `finally` block in `Start-TeaWebServer` and the AppDomain entry cleanup are both
  independent safeguards; either alone is sufficient for normal terminal exits; only
  AppDomain is sufficient for VS Code Extension kills.
- SIGKILL is out of scope. Users who force-kill the process must wait for the OS TCP
  TIME_WAIT to expire or choose a different port.
- Any future WebSocket driver must register its listener and CTS in the `PSTea.Active*`
  AppDomain slots and must capture `$logFile` as a local before defining any closures that
  write to the debug log.
