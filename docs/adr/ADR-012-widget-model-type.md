# ADR-012 — Widget Model Type: Hashtable vs. PSCustomObject

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | Phase 9 (Widget Library) |

## Context

All Phase 9 widget models were written as hashtable literals (`@{ Value = ''; ... }`). Every other
model in the framework uses `[PSCustomObject]@{}`. `Copy-ElmModel` uses a JSON roundtrip
(`ConvertTo-Json | ConvertFrom-Json`). In PS 5.1, `ConvertFrom-Json` always returns a
PSCustomObject — meaning a hashtable model silently becomes a PSCustomObject after the first
`Copy-ElmModel` call. Any type-checking code (`-is [hashtable]`) would silently break after the
first update cycle.

## Decision

**PSCustomObject.** All widget models use `[PSCustomObject]@{}`, consistent with every other
model in the framework.

## Rationale

The JSON roundtrip converts hashtables to PSCustomObjects anyway — using hashtables creates a
silent type change on the first `Copy-ElmModel` call. PSCustomObject is consistent with all other
models, makes type-checking reliable, and has identical dot-access syntax. There is no practical
benefit to using hashtables.

## Consequences

- All Phase 9 widget factory model definitions must use `[PSCustomObject]@{}`.
- Widget tests that check model type will use `-is [PSCustomObject]`.
