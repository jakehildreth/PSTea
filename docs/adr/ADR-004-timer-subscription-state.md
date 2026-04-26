# ADR-004 - Timer Subscription State Persistence

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | Phase 6 (Subscriptions), Phase 5 (Runtime) |

## Context

`Invoke-ElmSubscriptions` calls `& $SubscriptionsFn $Model` each cycle. The subscription function
calls `New-ElmTimerSub`, which returns a new object with `LastFired = $null` every time. Since
`$LastFired` is always null, every timer always appears "never fired" and fires on every 16ms
cycle regardless of its `IntervalMs` setting.

The root tension: subscriptions are a pure function of the model (they can change based on state),
but timers need mutable state (`LastFired`) that persists across cycles.

## Options Considered

| Option | Description |
|--------|-------------|
| **State on the object** | Factory returns object with `LastFired`; object mutated in place. Requires subs created once at startup, not per-cycle. |
| **State in a cache owned by the event loop** | `$SubCache` hashtable passed to `Invoke-ElmSubscriptions` each cycle; keyed by sub identity. |
| **State in the model** | Developer stores timer state in model; Update maintains it. |

## Decision

**`$SubCache` hashtable owned by the event loop.**

```powershell
# Initialized once before the loop:
$SubCache = @{}

# Passed each cycle:
Invoke-ElmSubscriptions -SubscriptionsFn $SubscriptionsFn -Model $Model -InputQueue $Driver.InputQueue -SubCache $SubCache
```

Cache key: `"Timer:$($Sub.IntervalMs)"`. `LastFired` is read from and written to `$SubCache`.
Timer objects returned by the subscription function remain pure value objects.

## Rationale

Storing state in the model conflates framework infrastructure with application logic. Creating subs
once at startup prevents model-driven subscription changes. A cache owned by the event loop keeps
subscription objects as pure value objects while providing the framework a place to persist runtime
state across cycles without leaking it into user-visible constructs.

## Consequences

- `Invoke-ElmSubscriptions` signature gains a `-SubCache [hashtable]` parameter.
- Stale cache entries (from removed timer subs) are harmless - they are never looked up.
- New timer subs (added mid-run) fire immediately on their first eligible cycle (no prior
  `LastFired`), which is the correct behavior.
- `Invoke-ElmSubscriptions` tests can inject a pre-populated `$SubCache` to control timer state.
