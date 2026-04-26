# ADR-019 - PowerShell Array Flattening in Table Widget Parameter

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | Phase 10 (`New-ElmTable`) |

## Context

`New-ElmTable` accepts `-Rows [object[]]` where each element is expected to be a `[string[]]`
(one row of cells). PowerShell's `@()` array subexpression operator **enumerates** its argument:

```powershell
@(@('Alice', '30'))   # enumerates @('Alice','30') → @('Alice','30')  FLATTENED
@(@('Alice', '30'), @('Bob', '25'))  # binary comma prevents flattening → 2-row table  OK
```

A single multi-column row wrapped in `@()` without a comma is silently flattened to a flat string
array, so `New-ElmTable` sees N single-column rows instead of one N-column row.

## Decision

**Document and enforce the unary comma convention. Do not attempt to auto-detect or work around
the flattening in the widget code.**

For a single row, the caller uses the unary comma operator:

```powershell
$row = @('Alice', '30', 'New York')
New-ElmTable -Rows @(,$row)        # unary comma wraps row in 1-element array
New-ElmTable -Rows (,$row)         # equivalent
```

For multiple rows, the binary comma between items is sufficient:

```powershell
New-ElmTable -Rows @(@('Alice','30'), @('Bob','25'))   # binary comma, no flattening
```

## Rationale

Detecting and reversing flattening would require heuristics (e.g., "if all elements are strings,
treat as a single row") that would silently misinterpret valid single-column tables. The unary
comma is idiomatic PowerShell for passing an array as a single element and is consistent with
how other cmdlets handle nested arrays.

## Consequences

- Public documentation and comment-based help for `New-ElmTable` must show the unary comma
  pattern for single-row tables.
- Test files use `@(,$row)` or `$row = @(...); @(,$row)` for single multi-column rows.
- The widget does not validate that rows are arrays (no practical way to distinguish a flat
  string from a single-element row after flattening has occurred).
