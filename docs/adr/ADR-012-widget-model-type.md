# ADR-012 — Widget Architecture: Pure View Functions vs. Full Component Triples

| Field    | Value |
|----------|-------|
| Status   | Accepted (supersedes original hashtable-vs-PSCustomObject scope) |
| Affects  | Phase 9 (Widget Library) |

## Context

The original Phase 9 plan specified widgets as full Init/Update/View component triples (like
BubbleTea models) with their own PSCustomObject models, typed message handlers, and encapsulated
state. A secondary question was whether those models should use `@{}` hashtables or
`[PSCustomObject]@{}`.

During implementation, a simpler design emerged: pure view functions that take rendering
parameters and return a view-tree node. The caller owns all state in their application model;
widgets are stateless renderers.

## Options Considered

| Option | Description |
|--------|-------------|
| **Full component triple** | Init + Update + View. Widget encapsulates its own model. Parent embeds sub-model and routes messages via `New-ElmComponentMsg`. |
| **Pure view function** | Stateless render function. Caller stores all widget state in their model and passes it as parameters each frame. |

## Decision

**Pure view functions.** Phase 9 widgets are stateless renderers:

```powershell
# Caller owns state; widget just renders
New-ElmTextInput -Value $model.InputText -CursorPos $model.Cursor -Focused:$model.Focused
New-ElmList      -Items $items -SelectedIndex $model.ListCursor -MaxVisible 10
New-ElmProgressBar -Value $model.Progress -Width 30
New-ElmSpinner   -Frame $model.Frame -Variant 'Braille'
New-ElmViewport  -Lines $lines -ScrollOffset $model.ScrollTop -MaxVisible 8
```

## Rationale

- **Simpler composition**: no sub-model embedding, no message routing boilerplate, no
  `New-ElmComponentMsg` wrapping for trivial widgets.
- **Consistent API**: same shape as `New-ElmText`, `New-ElmBox`, `New-ElmRow` — all pure
  view functions. Developers already know this pattern.
- **Framework already has components**: `New-ElmComponent` (Phase 8) exists for cases where
  genuine encapsulation is needed. Widgets that are just presentation don't need it.
- **PSCustomObject note** (original ADR scope): still applies wherever models are used. The JSON
  roundtrip in `Copy-ElmModel` converts hashtables to PSCustomObjects silently; always use
  `[PSCustomObject]@{}` for model definitions.

## Consequences

- Widget parameters are explicit and typed; callers tab-complete them.
- No Init/Update per widget; callers handle messages in their own Update function.
- Widget tests validate rendering output, not state transitions.
- Full component-model widgets remain possible via `New-ElmComponent` (Phase 8) when warranted.
