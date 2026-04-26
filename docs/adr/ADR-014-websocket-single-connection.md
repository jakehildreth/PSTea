# ADR-014 - WebSocket: Single Connection Policy

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | Phase 7 (WebSocket Driver - `Invoke-ElmWebSocketListener`) |

## Context

`AcceptWebSocketAsync()` on `System.Net.HttpListener` handles one connection at a time. If a
second browser tab connects, behavior is undefined without explicit handling.

## Decision

**Single connection only. Additional connection attempts receive a `409 Conflict` response with
a plain-text explanation.**

- The listener accepts the first WebSocket upgrade request.
- Subsequent `GET /ws` requests while a connection is active receive `409 Conflict` with body:
  `"A session is already active. Close the existing tab and refresh."`
- `GET /` (the HTML page) continues to serve normally regardless of connection state - the user
  can load the page again; they just can't open a second WebSocket session.
- This is documented as a v1 constraint. Multiple sessions are a v2 consideration.

## Rationale

One app instance = one user session. This is consistent with the model - there is a single
`$InputQueue` and `$OutputQueue`. Multiple connections sharing one queue would produce
non-deterministic input routing and interleaved output. A clear `409` is more developer-friendly
than undefined/silent behavior.

## Consequences

- `Invoke-ElmWebSocketListener` must track connection state (connected / not connected).
- `GET /ws` handler checks state before calling `AcceptWebSocketAsync`.
- Disconnection (tab close, network drop) must reset state so a reconnect is possible.
- Tests should cover: first connection accepted; second connection rejected with 409;
  reconnection after disconnect succeeds.
