# ADR-002 — InputQueue Ownership (Who Dequeues)

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | Phase 5 (Runtime), Phase 6 (Subscriptions) |

## Context

The original plan had the event loop calling `TryDequeue` directly on `$InputQueue` AND passing
`$InputQueue` to `Invoke-ElmSubscriptions` for key subscription callbacks. `ConcurrentQueue`
supports `TryPeek` only for the first item — there is no non-destructive full-queue scan. This
creates a race: either the event loop consumes a key before subscriptions see it, or subscriptions
consume it and the loop misses it.

## Options Considered

| Option | Description |
|--------|-------------|
| **Event loop dequeues** | Loop calls `TryDequeue`; subscriptions see only what remains. |
| **Subscriptions dequeue** | `Invoke-ElmSubscriptions` is the sole consumer; loop never touches the queue. |
| **Shared ownership** | Coordination primitives divide items between consumers. |

## Decision

**Subscriptions are the sole consumer.** `Invoke-ElmSubscriptions` drains `$InputQueue` via a
`TryDequeue` loop each cycle. The event loop never calls `TryDequeue` directly.

## Rationale

Two consumers on one queue with no coordination guarantee produce non-deterministic behavior.
Shared ownership requires synchronization primitives that add complexity and new failure modes.
Subscriptions already own the `OnKey` callbacks that map keys to messages — they are the natural
and complete home for key event handling.

## Consequences

- `Quit` is no longer a special case in the event loop — it is a normal message returned by a
  subscription's `OnKey` callback, handled uniformly alongside all other messages.
- If the developer registers no `New-ElmKeySub`, keyboard input is silently ignored. This is
  consistent with Elm's model and must be documented.
- `Invoke-ElmSubscriptions` must drain the full queue each cycle, not just peek.
