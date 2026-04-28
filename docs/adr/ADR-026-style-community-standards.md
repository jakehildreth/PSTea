# ADR-026 - PowerShell Style and Community Standards Remediation

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | All Private/ and Public/ functions, Tests/, Examples/ |

## Context

A full style audit of the PSTea codebase revealed several deviations from PowerShell
community standards and module authoring best practices. No functional behavior was broken,
but the codebase had accumulated patterns that reduce discoverability, IDE experience, and
long-term maintainability:

1. Multiple functions defined in a single `.ps1` file (community standard: one function
   per file, named to match).
2. Private helper functions using an `_` prefix convention (no equivalent in PowerShell
   community standards; `_Verb-Noun` is not a valid approved verb).
3. `[CmdletBinding()]` missing from several private functions.
4. Comment-based help (CBH) missing from all private functions.
5. `[OutputType()]` missing from all public functions.
6. `throw` used instead of `$PSCmdlet.ThrowTerminatingError()` in a cmdlet-bound function.
7. A hashtable returned where a `[PSCustomObject]` is the community-preferred type.
8. Backtick (`` ` ``) used for line continuation throughout; splatting is the idiomatic
   PowerShell alternative.
9. Several single-line hashtable entries exceeding ~200 characters with no multiline
   formatting.

## Decisions

### One function per file (S12)
Each function gets its own `.ps1` file named to match the function. Files with multiple
functions are split. This is the PowerShell community standard and makes module
dot-sourcing, navigation, and diffing simpler.

### Drop underscore prefix (S12 / S2)
The `_Verb-Noun` naming convention has no basis in PowerShell standards. Extracted helper
functions are renamed to drop the prefix (e.g. `_ConvertFrom-AnsiCsi` ->
`ConvertFrom-AnsiCsi`). Internal call sites are updated accordingly.

### [CmdletBinding()] on all functions (S4)
Every function — public and private — gets `[CmdletBinding()]`. This enables `-Verbose`,
`-Debug`, `-ErrorAction`, and `$PSCmdlet` access consistently across the codebase.

### Comment-based help on all functions (S5)
Every function — public and private — gets formal CBH (`.SYNOPSIS`, `.DESCRIPTION`,
`.PARAMETER`, `.OUTPUTS`). Private helpers get abbreviated CBH appropriate to their role.
This enables `Get-Help` on any function when debugging.

### [OutputType()] on all public functions (S7)
All public functions declare `[OutputType([PSCustomObject])]`. This improves IDE
parameter inference, `Get-Help -Full` output, and tab completion accuracy.

### ThrowTerminatingError over throw (S3)
`throw "string"` replaced with `$PSCmdlet.ThrowTerminatingError()` using a typed
`[System.Management.Automation.ErrorRecord]`. This produces structured errors with a
proper `ErrorCategory`, participates in `-ErrorAction`, and is the standard for
cmdlet-bound functions. The sole exception is script-level code in `PSTea.psm1` where
`$PSCmdlet` is unavailable — `Write-Error` is acceptable there.

### [PSCustomObject] over hashtable for structured returns (S6)
`Invoke-TeaDriverLoop` returned a plain hashtable. Changed to `[PSCustomObject]@{}`.
PSCustomObjects have a defined type, display with consistent formatting, and signal
intent more clearly than hashtables.

### Splatting over backtick line continuation (S11)
All backtick line continuations in functional code, test files, CBH `.EXAMPLE` blocks,
and example scripts are replaced with splatted parameter hashtables. Splatting is the
PowerShell community idiom; backticks are fragile (invisible trailing whitespace breaks
them) and reduce readability.

### Multiline formatting for long hashtable entries (S9)
Hashtable entries exceeding ~120 characters are split into multiline format. This applies
specifically to the border character map in `ConvertTo-BorderChars.ps1`.

## Consequences

- ~35 files changed (no behavior changes except S6 return type, which is compatible).
- 9 new `.ps1` files created (extracted helpers).
- `PSTea.psm1` is unaffected: its recursive `Get-ChildItem` dot-source loop auto-discovers
  the new files.
- Test `BeforeAll` blocks that dot-source split files must be updated to include the new
  files.
- One new test assertion added: `Invoke-TeaDriverLoop` return value `Should -BeOfType
  [PSCustomObject]`.
- CalVer versioning (`ModuleVersion`) deferred to first release — not part of this ADR.
- A debug logging subsystem (`-Debug` switch on `Start-TeaProgram`) is deferred as a
  separate feature (see session notes).
