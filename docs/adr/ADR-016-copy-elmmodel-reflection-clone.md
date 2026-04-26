# ADR-016 - `Copy-ElmModel` Uses Reflection-Based Clone Instead of JSON Roundtrip

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | Phase 5 (Runtime - `Copy-ElmModel`, `Invoke-ElmUpdate`) |

## Context

`Copy-ElmModel` deep-clones the model before passing it to the user's `UpdateFn`, ensuring
the original model is never mutated (TEA immutability guarantee). The initial implementation
used a JSON roundtrip:

```powershell
$Model | ConvertTo-Json -Depth 20 | ConvertFrom-Json
```

This approach was correct for correctness but expensive at runtime. `Invoke-ElmUpdate` is
called on every message - every keypress and every tick. For tick-driven demos at 100-150ms
intervals that is 6-10 roundtrips per second. For interactive demos with complex models
(Quiz with a questions array, Snake with a growing body array) the cost was measurable as
input latency and sluggish rendering.

The JSON roundtrip also has a correctness hazard: it silently destroys typed .NET objects
(`[DateTime]`, `[TimeSpan]`, `[FileInfo]`, etc.) by converting them to strings or plain
`PSCustomObject` trees. This required models to be restricted to JSON-safe primitives, which
was an implicit constraint with no enforcement.

## Decision

Replace the JSON roundtrip with a recursive reflection-based clone (`Copy-ElmModelValue`).
The helper walks the object graph directly:

- `$null` → `$null`
- `[System.Array]` → new `[object[]]` with each element recursively cloned; returned via
  `Write-Output -NoEnumerate` to preserve array identity through the PowerShell pipeline
- `[PSCustomObject]` → new `[PSCustomObject]` built from an ordered hashtable of recursively
  cloned property values
- All other values (strings, ints, longs, bools, enums) → returned as-is (value types or
  immutable reference types)

## Rationale

- **Performance**: no string allocation, no JSON parser invocation, no Depth limit traversal.
  For a flat model of 5-10 primitive properties, the reflection clone is an order of magnitude
  faster.
- **Correctness**: typed .NET objects are still passed by reference (not cloned), which matches
  the documented constraint that models should contain only primitives. The behavior is no
  worse than before, and the code path is now explicit rather than silently destructive.
- **Simplicity**: the helper is ~20 lines of straightforward recursion with no external
  dependencies.

## Consequences

- `Copy-ElmModel` no longer silently converts `[DateTime]`/`[TimeSpan]`/etc. to strings -
  it passes them by reference. Models containing typed objects will not crash, but mutations
  to those objects inside `UpdateFn` will affect the original model. The documented contract
  (models must be primitives) is unchanged.
- Arrays are preserved as `[object[]]`. Code that checks for a specific array type may need
  to use `@()` wrapping, which is already standard practice in PS.
- The `Write-Output -NoEnumerate` pattern is required to return arrays through the
  PowerShell pipeline without unwrapping them into scalar values.
