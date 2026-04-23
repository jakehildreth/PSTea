# ADR-006 — Background Runspace Module Loading

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | Phase 5 (Runtime — `Invoke-ElmDriverLoop`) |

## Context

Background runspaces in PS 5.1 do not inherit the parent session's loaded modules. Driver input
and output runspaces need access to module functions (e.g., `ConvertFrom-ElmKeyString`). The plan
did not specify how the module is made available inside these runspaces.

## Options Considered

| Option | Description |
|--------|-------------|
| **`InitialSessionState.ImportPSModule`** | Import the module by name or path when creating the runspace. |
| **Inject functions as scriptblock parameters** | Serialize required functions and pass them as named parameters on the `PowerShell` instance. |
| **Try/fallback — both** | Attempt module import first; fall back to scriptblock injection if import fails; emit a warning in fallback mode. |

## Decision

**Try/fallback.** `Invoke-ElmDriverLoop` uses the following strategy:

1. Attempts `$ISS.ImportPSModule($ModulePath)` where `$ModulePath` defaults to the module's own
   `$PSScriptRoot`.
2. On failure, injects the minimum required functions as serialized scriptblock parameters on the
   `PowerShell` instance.
3. Emits `Write-Warning` indicating fallback mode so the developer is aware.

`Invoke-ElmDriverLoop` accepts an optional `-ModulePath [string]` parameter for explicit override.

## Rationale

Module import covers the installed case cleanly. Scriptblock injection covers dev/source scenarios
where the module is not on `PSModulePath`. Neither alone handles all environments. Try/fallback
with a warning provides maximum robustness without requiring the developer to configure anything.

## Consequences

- `Invoke-ElmDriverLoop` gains a `-ModulePath [string]` optional parameter.
- A list of "minimum required functions" for scriptblock injection must be maintained.
- Tests should exercise both the import-success and import-failure paths.
