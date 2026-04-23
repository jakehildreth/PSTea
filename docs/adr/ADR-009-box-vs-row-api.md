# ADR-009 — `New-ElmBox` vs. `New-ElmRow` API

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | Phase 3 (View DSL) |

## Context

The module structure listed both `New-ElmBox.ps1` and `New-ElmRow.ps1` as separate files. Phase 3
deliverables described `New-ElmBox` as implicitly vertical, but the example code used
`New-ElmBox -Direction Vertical`. The plan was internally inconsistent. LipGloss (a primary design
influence) uses two distinct functions — `JoinHorizontal` and `JoinVertical` — rather than a
single function with a direction parameter.

## Options Considered

| Option | Description |
|--------|-------------|
| **Single function with `-Direction`** | `New-ElmBox -Direction Vertical/Horizontal`. One function, direction explicit as parameter. |
| **Two named functions** | `New-ElmBox` (vertical) and `New-ElmRow` (horizontal). Direction implicit in name. |
| **Both** | `New-ElmBox -Direction` canonical; `New-ElmRow` as a thin shorthand wrapper. |

## Decision

**Two named functions.** `New-ElmBox` produces a vertical stack; `New-ElmRow` produces a
horizontal stack. Neither takes a `-Direction` parameter.

```powershell
New-ElmBox -Children @(
    New-ElmRow -Children @($Left, $Right)
    New-ElmText 'footer'
)
```

## Rationale

LipGloss, a primary design influence, uses two distinct named operations (`JoinVertical`,
`JoinHorizontal`) rather than one parameterized function. Two named functions produce more
readable call sites — direction is conveyed by the function name, not a recurring `-Direction`
parameter at every call site.

## Consequences

- `New-ElmBox.ps1` always produces `Direction = 'Vertical'` nodes; no `-Direction` parameter.
- `New-ElmRow.ps1` always produces `Direction = 'Horizontal'` nodes; no `-Direction` parameter.
- All example code in the plan and documentation must use `New-ElmRow` for horizontal layouts.
- The Box node schema retains a `Direction` field internally for the layout engine; it is set by
  the factory, not by the caller.
