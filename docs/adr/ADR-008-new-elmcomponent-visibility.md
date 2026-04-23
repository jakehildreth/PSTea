# ADR-008 — `New-ElmComponent` Visibility (Public vs. Internal)

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | Phase 8 (Component Model) |

## Context

The plan said `New-ElmComponent` should "consider internal" but it is called directly in View
scriptblocks written by the developer. If it is private, developers cannot use it.

## Decision

**Public.** `New-ElmComponent` is exported in `FunctionsToExport` with full comment-based help.

## Rationale

It is called in user-authored View functions. There is no mechanism for a private function to be
accessible from a scriptblock defined outside the module. The "consider internal" note in the
original plan was an error — the usage pattern makes the visibility requirement unambiguous.

## Consequences

- `New-ElmComponent` gets `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.OUTPUTS`
  comment-based help, per the framework's conventions for all public functions.
- It is added to `FunctionsToExport` in `Elm.psd1`.
- ADR-007 cross-reference: `New-ElmComponent` creates a node that `Measure-ElmViewTree` expands
  during the layout pass (not at render time).
