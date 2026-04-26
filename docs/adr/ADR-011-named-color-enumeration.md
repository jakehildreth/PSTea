# ADR-011 - Named Color Enumeration and Color Profile Downsampling

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | Phase 2 (Style System - `Resolve-ElmColor`) |

## Context

`Resolve-ElmColor` was described as mapping "a reasonable set" of named colors. Without an
explicit enumeration, `[ValidateSet(...)]` cannot be defined and tests cannot be authored.
Additionally, not all terminals support truecolor (`#RRGGBB`) or even 256-color - emitting
unsupported sequences produces incorrect or garbled output. LipGloss handles this by
automatically downsampling colors to the best available profile for the terminal.

## Decision

### Named Color Set

Exactly 16 named constants, matching the 16 standard ANSI colors and `[System.ConsoleColor]`:

```
Black, Red, Green, Yellow, Blue, Magenta, Cyan, White
BrightBlack, BrightRed, BrightGreen, BrightYellow
BrightBlue, BrightMagenta, BrightCyan, BrightWhite
```

All other colors use hex (`'#FF8800'`) or 256-index (`201`). No `Orange`, `Pink`, `Purple` etc.
as named constants - those are achievable via hex or 256-index and do not need named aliases.

### Color Profile Detection and Downsampling

Not implemented. The framework targets terminals with ANSI support. PowerShell ISE is explicitly
out of scope - it does not support ANSI escape sequences and is not a supported host.

`Resolve-ElmColor` always emits the ANSI sequence matching the requested color type:
- Named color → 16-color ANSI SGR sequence
- Hex → truecolor `ESC[38;2;R;G;Bm` / `ESC[48;2;R;G;Bm`
- 256-index → `ESC[38;5;Nm` / `ESC[48;5;Nm`

No environment variable detection. No downsampling. No `-Profile` parameter.

## Rationale

Automatic downsampling means developer code never needs to branch on terminal capabilities.
A hex color specified in a style renders correctly whether the user has a truecolor terminal,
an SSH session with 256-color, or an old 16-color console. Matches LipGloss behavior and the
`NO_COLOR` standard (https://no-color.org/).

## Consequences

- `Resolve-ElmColor` gains color profile detection logic (or calls a `Get-ElmColorProfile`
  private helper that can be mocked in tests).
- `Resolve-ElmColor` gains an optional `-Profile` parameter for test overrides.
- `[ValidateSet]` on named color input can now be fully defined.
- Tests must cover: named color at each profile level, hex downsampled to 256 and 16,
  `NO_COLOR` env var suppresses all output.
