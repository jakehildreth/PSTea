# ADR-007 - Component Node Expansion: Measure Pass vs. Render Pass

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | Phase 3 (Measure), Phase 8 (Component Model) |

## Context

Phase 8 originally said `ConvertTo-AnsiOutput` should handle Component nodes by calling `ViewFn`
with `SubModel` at render time. However, `Measure-ElmViewTree` runs before rendering and assigns
`X`/`Y`/`Width`/`Height` to every node. If components expand during render, the layout engine
never measured the component's actual content - surrounding node positions are based on placeholder
dimensions and are incorrect.

## Options Considered

| Option | Description |
|--------|-------------|
| **Expand at render time** | `ConvertTo-AnsiOutput` calls `ViewFn` lazily. Layout is approximate. |
| **Expand during the measure pass** | `Measure-ElmViewTree` expands Component nodes recursively; renderer and differ never see raw Component nodes. |

## Decision

**Expand during the measure pass.** When `Measure-ElmViewTree` encounters `Type = 'Component'`,
it calls `& $Node.ViewFn $Node.SubModel`, recursively measures the resulting subtree within the
available space, and substitutes the expanded measured subtree in place of the Component node.

`ConvertTo-AnsiOutput`, `ConvertTo-AnsiPatch`, and `Compare-ElmViewTree` operate exclusively on
fully-expanded measured trees. They never encounter raw Component nodes.

## Rationale

Layout correctness requires that every node's dimensions are known before positions are assigned.
Lazy expansion at render time means the flexbox pass operates on placeholder dimensions, producing
incorrect layouts for any component whose height or width depends on its content.

## Consequences

- `Measure-ElmViewTree` gains a branch for `Type = 'Component'`.
- Component expansion happens exactly once per cycle, during the measure pass.
- `Compare-ElmViewTree` naturally diffs component content changes as part of the expanded tree.
- `Measure-ElmViewTree` tests should include Component node cases with nested components.
