# ADR-003 - ANSI Output Function Signatures

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | Phase 3 (View/Layout), Phase 4 (Diff Engine), Phase 5 (Runtime) |

## Context

Phase 3 defined `ConvertTo-AnsiOutput -Root` (walks a full measured view tree and emits ANSI for
every node). The Phase 5 event loop pseudo-code called `ConvertTo-AnsiOutput -Patches` (applies a
list of positioned diffs). These are fundamentally different operations with different inputs,
different logic, and different outputs. Defining them as one function also embeds first-render
detection inside the function, which requires it to carry state.

## Options Considered

| Option | Description |
|--------|-------------|
| **One function, two parameter sets** | `ConvertTo-AnsiOutput` accepts either `-Root` or `-Patches`. |
| **Two separate functions** | `ConvertTo-AnsiOutput -Root` and `ConvertTo-AnsiPatch -Patches`. |

## Decision

**Two separate functions:**

- `ConvertTo-AnsiOutput -Root` - full frame render. Walks the measured tree, emits `ESC[2J` +
  all node positions. Used on first render and after any `FullRedraw` patch.
- `ConvertTo-AnsiPatch -Patches` - incremental render. Iterates patch list, emits only changed
  cursor-position + content sequences.

The event loop selects which to call:

```powershell
if ($null -eq $PrevTree -or ($Patches | Where-Object Type -eq 'FullRedraw')) {
    $Output = ConvertTo-AnsiOutput -Root $Measured
} else {
    $Output = ConvertTo-AnsiPatch -Patches $Patches
}
```

## Rationale

Single-responsibility principle. The two operations share no logic. One function with two modes
complicates testing, obscures intent at call sites, and forces the function to carry state for
first-render detection. Two functions are independently testable and the caller is the right place
for the full-vs-incremental decision.

## Consequences

- `ConvertTo-AnsiPatch.ps1` is a new file added to `Private/Rendering/`.
- First-render detection (`$null -eq $PrevTree`) belongs to `Invoke-ElmEventLoop`, not to either
  render function.
- `ConvertTo-AnsiOutput` no longer needs to track whether it is being called for the first time.
