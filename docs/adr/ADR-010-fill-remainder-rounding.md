# ADR-010 — `Fill` Remainder Distribution Strategy

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | Phase 3 (Flexbox Layout — `Measure-ElmViewTree`) |

## Context

When multiple `Fill` children divide available space, integer division produces a remainder.
Example: 3 Fill children in 79 columns → 26 + 26 + 27 = 79. One child gets an extra column.
The plan said "divide equally" but did not specify which child receives the remainder.

## Options Considered

| Option | Description |
|--------|-------------|
| **Last child gets remainder** | Remainder goes to the rightmost/bottommost Fill child. Matches CSS flex behavior. |
| **First child gets remainder** | Remainder goes to the leftmost/topmost child. |
| **Round-robin** | Each extra unit goes to the next child in sequence. Most "fair" but complex. |

## Decision

**Last child gets remainder.** The final `Fill` child in the layout order receives any extra
columns/rows that result from integer division.

```
79 cols ÷ 3 Fill children = 26 remainder 1
→ child 1: 26, child 2: 26, child 3: 27
```

## Rationale

Matches CSS flexbox behavior. Simple to implement (`$LastFillChild.Width += $Remainder`) and
simple to reason about when debugging layouts.

## Consequences

- `Measure-ElmViewTree` must identify the last `Fill` child in each container during Pass 2.
- Tests should include cases with non-zero remainders and verify the last child receives them.
