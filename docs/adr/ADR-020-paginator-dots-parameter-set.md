# ADR-020 - Consolidate Paginator Variants into New-ElmPaginator Parameter Sets

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | Phase 10 (`New-ElmPaginator`) |

## Context

After initial delivery, a dot-style paginator (`○ ○ ● ○ ○`) was requested. The first
implementation created a separate `New-ElmDotPaginator` function. This raised the question of
whether dot pagination belongs alongside the existing `Numeric` and `Tabs` parameter sets in
`New-ElmPaginator`, or as a peer function.

## Decision

**Merge Dots mode into `New-ElmPaginator` as a third parameter set (`Dots`), and delete the
standalone `New-ElmDotPaginator.ps1`.**

The `Dots` parameter set is selected via a mandatory `[switch]$Dots` parameter:

```powershell
# Numeric (default - backward compatible)
New-ElmPaginator -CurrentPage 3 -PageCount 7

# Dots with Unicode defaults (requires UTF-8 console - provided by New-ElmTerminalDriver)
New-ElmPaginator -Dots -CurrentPage 3 -PageCount 7

# Dots with ASCII fallback for legacy terminals
New-ElmPaginator -Dots -CurrentPage 3 -PageCount 7 -FilledDot '*' -EmptyDot '-'

# Named tabs - unchanged
New-ElmPaginator -Tabs @('A','B','C') -ActiveTab 1
```

## Disambiguation via -Dots Switch

`-CurrentPage` and `-PageCount` are shared mandatory parameters across both `Numeric` and `Dots`
parameter sets. Without a discriminating parameter, PowerShell cannot determine which set to use
when only those two are provided, because the `DefaultParameterSetName = 'Numeric'` resolution
falls through before validating unique params.

A mandatory `[switch]$Dots` solves this cleanly:
- No extra token needed for the common all-defaults case: `-Dots` is a single switch
- Reads naturally as a mode selector
- Keeps `-FilledDot`, `-EmptyDot`, `-Separator` optional with sensible defaults

Rejected alternatives:
- **Separate function** - Splits conceptually related navigation widgets across the API surface;
  callers have to remember two names
- **-FilledDot as mandatory** - Forces callers to supply a char they don't want to customize;
  ergonomically bad
- **Infer from presence of -FilledDot/-EmptyDot** - Can't get dots-with-all-defaults; ambiguity
  when only `Numeric`-compatible params are passed

## Unicode Dot Characters

Default `FilledDot` is `●` (U+25CF) and `EmptyDot` is `○` (U+25CB). Both are in the Basic
Multilingual Plane and render correctly in any UTF-8 terminal. `New-ElmTerminalDriver` now
enforces UTF-8 encoding (see ADR for terminal driver), so these defaults are safe for all Elm
programs. ASCII overrides (`-FilledDot '*' -EmptyDot '-'`) remain available for scenarios where
the driver is not used.

## Consequences

- `New-ElmDotPaginator.ps1` is deleted; all dot functionality is in `New-ElmPaginator.ps1`
- Existing `Numeric` and `Tabs` callers are unaffected (no param changes)
- `New-ElmPaginator.Tests.ps1` gains a `Dots mode` Context block (15 tests)
- Demo `Invoke-WidgetShowcaseDemo.ps1` can add Dots mode to the Paginator panel using `-Dots`
