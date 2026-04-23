# ADR-015 — `Apply-ElmStyle` Multi-Line Border Rendering

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | Phase 2 (Style System — `Apply-ElmStyle`) |

## Context

`Apply-ElmStyle` adds border characters around styled content. The plan specified top-row
(`TL`/`T`/`TR`) and bottom-row (`BL`/`B`/`BR`) characters but did not define behavior for
multi-line content — specifically whether `L` and `R` side characters are repeated on each
interior line.

## Decision

**Side chars on every interior line.** Each content line is rendered as `L + content + R`.

```
╭─────────╮
│ line 1  │
│ line 2  │
│ line 3  │
╰─────────╯
```

## Rationale

This is standard box-drawing convention. A border that only has a top and bottom row with no
sides is not a box — it is two horizontal rules. Every TUI framework renders borders this way.

## Consequences

- `Apply-ElmStyle` must split multi-line content on `\n` and prepend `L` + append `R` to each
  interior line before adding the top and bottom border rows.
- Content width must be consistent across all lines (padding to the widest line before bordering).
- Tests must include multi-line content cases.
