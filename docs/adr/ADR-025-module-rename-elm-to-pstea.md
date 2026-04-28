# ADR-025 - Module Renamed from Elm to PSTea

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | All public functions, module manifest, private helpers, tests, examples |

## Context

The module was originally named "Elm" because it implements The Elm Architecture (TEA) - the
Model-Update-View pattern introduced by the Elm programming language. However, Elm is a
language. This module replicates the architecture that Elm introduced; it is not a port of
the language itself, and naming it "Elm" misrepresents that relationship.

The name also creates a practical problem: users searching for the Elm language may find
this module, and users looking for a PowerShell TEA framework may not find it because they
do not know to search for "Elm."

Inspiration for the module comes from two Go TUI frameworks that faced the same naming
question and solved it well:

- **BubbleTea** - implements TEA in Go without claiming to be Elm
- **Textual** - implements a similar architecture in Python under its own name

## Decision

**Rename the module from `Elm` to `PSTea` with command prefix `Tea`.**

- Module manifest: `Elm.psd1` -> `PSTea.psd1`
- Root module: `Elm.psm1` -> `PSTea.psm1`
- All public function names: `*-Elm*` -> `*-Tea*`
  - e.g. `New-ElmBox` -> `New-TeaBox`, `Start-ElmProgram` -> `Start-TeaProgram`
- All private function names follow the same `Tea` prefix convention
- Debug log path: `/tmp/elm-web-debug.log` -> `/tmp/pstea-web-debug.log`
- Internal C# helper type: `ElmConsoleHelper` -> `TeaConsoleHelper`
- Default web title: `'Elm TUI'` -> `'PSTea TUI'`
- The stub function `New-Elm` is deleted (it was dead code)

The module name `PSTea` and the command prefix `Tea` are intentionally different, following
the established PowerShell convention where the module name and command prefix differ (e.g.
the `ActiveDirectory` module exports `Get-ADUser`, not `Get-ActiveDirectoryUser`). `PSTea`
is discoverable and clearly PowerShell-specific; `Tea` keeps function names concise and
readable.

## Rationale

- **Accuracy**: PSTea describes what the module is - a PowerShell implementation of TEA.
  It does not claim to be the Elm language.
- **Discoverability**: Searching "PowerShell TEA" or "PowerShell BubbleTea" will surface
  PSTea more naturally than searching "PowerShell Elm."
- **Precedent**: BubbleTea and Textual both implement TEA-style architectures under their
  own names rather than calling themselves "Elm."
- **Readability**: `New-TeaBox`, `Start-TeaProgram` read cleanly. `New-PSTeaBox` would
  visually blur the "PS" and "Tea" components together.

## Consequences

This is a breaking change for all existing consumers.

- All `New-Elm*`, `Start-Elm*`, `Invoke-Elm*`, `Get-Elm*`, `Copy-Elm*`, `Measure-Elm*`,
  `Compare-Elm*`, `Apply-Elm*`, `Resolve-Elm*`, `ConvertFrom-Elm*` calls must be updated
  to the `*-Tea*` equivalents.
- `Import-Module Elm` must be updated to `Import-Module PSTea`.
- All dot-source paths referencing `*Elm*.ps1` must be updated.
- The module is pre-1.0 and has no published release, so no deprecation period is required.
