# ADR-013 - `Quit` as Framework Contract vs. Application-Defined Exit

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | Phase 5 (Runtime - `Invoke-ElmEventLoop`) |

## Context

The original plan hardcoded `'Quit'` as the exit signal. With ADR-002 (subscriptions as sole
queue consumer), `Quit` now flows through the subscription layer like any other message. It is
still a magic string - if a developer uses `'Exit'` or `'Done'`, the loop never exits.

## Decision

**Both: `'Quit'` is a reserved type AND `Ctrl+C` exits gracefully.**

- The event loop recognizes `Type = 'Quit'` as a framework-reserved exit signal and exits cleanly.
- `Ctrl+C` (SIGINT) is also handled - the event loop wraps its body in a `try/finally` block;
  `[Console]::TreatControlCAsInput = $false` is left at default so Ctrl+C raises a terminating
  exception that falls through to the `finally` block for cleanup.
- `'Quit'` is documented as a reserved message type. Developers must not use it for other
  purposes.

## Rationale

Developers expect Ctrl+C to always work. `'Quit'` as a reserved type gives the framework a clean
programmatic exit path. Both together match BubbleTea's behavior (`tea.Quit` command + Ctrl+C).

## Consequences

- `'Quit'` must be documented as a reserved `Type` value in the framework's public API.
- The event loop `finally` block must restore terminal state (show cursor, `ESC[0m`, re-enable
  echo) regardless of exit path.
- Tests should cover both exit paths: `Quit` message and simulated Ctrl+C termination.
