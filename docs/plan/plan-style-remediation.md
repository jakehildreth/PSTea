# Plan: PowerShell Style and Community Standards Remediation

## Status: In Progress

## Rationale

A full audit of PSTea found 8 style/community-standards issues. None affect functionality
but all reduce discoverability, IDE experience, and maintainability. See ADR-026 for the
decision record.

## Summary of Approved Changes

| Issue | Description | Priority |
|-------|-------------|----------|
| S3 | `throw` -> `$PSCmdlet.ThrowTerminatingError()` | HIGH |
| S4 | `[CmdletBinding()]` on all private functions | HIGH |
| S5 | CBH on all private functions | HIGH |
| S6 | Hashtable -> `[PSCustomObject]` in `Invoke-TeaDriverLoop` | MEDIUM |
| S7 | `[OutputType([PSCustomObject])]` on all public functions | MEDIUM |
| S9 | Long lines in `ConvertTo-BorderChars.ps1` | LOW |
| S11 | Remove all backtick continuations; replace with splatting | HIGH |
| S12 | One function per file; drop `_` prefix on helpers | HIGH |

Skipped: S1 (CalVer — defer to release), S8 (Write-Verbose — separate logging feature), S10 (psm1 script-level Write-Error — no alternative).

---

## Phase 0 - Documentation (do first)

- [x] Create `docs/adr/ADR-026-style-community-standards.md`
- [x] Create `docs/plan/plan-style-remediation.md` (this file)

---

## Phase 1 - File Splits (S12)

Split all multi-function files. `PSTea.psm1` auto-discovers new files via recursive
`Get-ChildItem` — no psm1 changes needed.

- [ ] `Private/Rendering/Measure-TeaViewTree.ps1` -> extract `Resolve-TeaDimension.ps1`, `Invoke-TeaPass1.ps1`, `Invoke-TeaPass2.ps1`; update `Tests/Measure-TeaViewTree.Tests.ps1` BeforeAll
- [ ] `Private/Rendering/Compare-TeaViewTree.ps1` -> extract `Get-TextLeaves.ps1`; update `Tests/Compare-TeaViewTree.Tests.ps1` BeforeAll
- [ ] `Private/Core/Copy-TeaModel.ps1` -> extract `Copy-TeaModelValue.ps1`; update `Tests/Copy-TeaModel.Tests.ps1` BeforeAll
- [ ] `Private/Web/ConvertFrom-AnsiVtSequence.ps1` -> extract `ConvertFrom-AnsiCsi.ps1`, `ConvertFrom-AnsiModCode.ps1`, `ConvertFrom-AnsiCharToConsoleKey.ps1` (drop `_` prefix); update call sites; update `Tests/ConvertFrom-AnsiVtSequence.Tests.ps1` BeforeAll; preserve line 309 literal `` ` `` in switch comment
- [ ] `Private/Drivers/Invoke-TeaWebSocketListener.ps1` -> extract `Write-TeaWebDebug.ps1`

---

## Phase 2 - [CmdletBinding()] + CBH (S4, S5)

All parallel.

New helper files (all need both `[CmdletBinding()]` and CBH):
- [ ] `Resolve-TeaDimension.ps1`
- [ ] `Invoke-TeaPass1.ps1`
- [ ] `Invoke-TeaPass2.ps1`
- [ ] `Get-TextLeaves.ps1`
- [ ] `Copy-TeaModelValue.ps1`
- [ ] `ConvertFrom-AnsiCsi.ps1`
- [ ] `ConvertFrom-AnsiModCode.ps1`
- [ ] `ConvertFrom-AnsiCharToConsoleKey.ps1`
- [ ] `Write-TeaWebDebug.ps1`

Existing files needing updates:
- [ ] `Private/Rendering/Enable-VirtualTerminal.ps1` — add `[CmdletBinding()]` + CBH
- [ ] `Private/Runtime/Invoke-TeaEventLoop.ps1` — add CBH
- [ ] `Private/Runtime/Invoke-TeaView.ps1` — add CBH
- [ ] `Private/Runtime/Invoke-TeaDriverLoop.ps1` — add CBH
- [ ] `Private/Style/Apply-TeaStyle.ps1` — add CBH
- [ ] `Private/Style/Resolve-TeaColor.ps1` — add CBH
- [ ] `Private/Style/ConvertTo-BorderChars.ps1` — add CBH
- [ ] `Private/Drivers/New-TeaTerminalDriver.ps1` — add CBH

---

## Phase 3 - [OutputType()] (S7)

All parallel. Add `[OutputType([PSCustomObject])]` above `[CmdletBinding()]` on every function in `Public/`.

- [ ] All files in `Public/Components/`
- [ ] All files in `Public/Drivers/`
- [ ] All files in `Public/Runtime/`
- [ ] All files in `Public/Style/`
- [ ] All files in `Public/Subscriptions/`
- [ ] All files in `Public/View/`

---

## Phase 4 - ThrowTerminatingError (S3)

- [ ] `Public/Runtime/Start-TeaWebServer.ps1`: replace `throw "Port $Port..."` with `$PSCmdlet.ThrowTerminatingError()` using `ErrorRecord` category `ResourceUnavailable`
- [ ] Verify `Tests/Start-TeaWebServer.Tests.ps1` error-path test still passes

---

## Phase 5 - PSCustomObject Return (S6) — TDD

- [ ] `Tests/Invoke-TeaDriverLoop.Tests.ps1`: add `It 'Should return a PSCustomObject'` asserting `$result -is [PSCustomObject]` (test will fail until next step)
- [ ] `Private/Runtime/Invoke-TeaDriverLoop.ps1`: change `@{...}` return to `[PSCustomObject]@{...}`
- [ ] Run tests; confirm new assertion passes and no regressions

---

## Phase 6 - Backtick Removal (S11)

Functional code:
- [ ] `Public/Runtime/Start-TeaWebServer.ps1` — splat `Invoke-TeaWebSocketListener` call
- [ ] `Public/Runtime/Start-TeaProgram.ps1` — splat `Invoke-TeaEventLoop` call
- [ ] `Public/Drivers/New-TeaWebSocketDriver.ps1` — splat call

CBH `.EXAMPLE` blocks:
- [ ] `Public/View/New-TeaTextarea.ps1`
- [ ] `Public/View/New-TeaTextInput.ps1`
- [ ] `Public/View/New-TeaList.ps1`
- [ ] `Public/View/New-TeaPaginator.ps1`
- [ ] `Public/Components/New-TeaComponent.ps1`
- [ ] `Public/View/New-TeaTable.ps1`
- [ ] `Public/Drivers/New-TeaWebSocketDriver.ps1`
- [ ] `Public/Runtime/Start-TeaWebServer.ps1`

Test files:
- [ ] `Tests/Invoke-TeaEventLoop.Tests.ps1` lines 101, 117
- [ ] `Tests/Start-TeaWebServer.Tests.ps1` line 90

Examples:
- [ ] `Examples/Invoke-WidgetShowcaseDemo.ps1`
- [ ] `Examples/Invoke-WidgetShowcaseWeb.ps1`

---

## Phase 7 - Long Lines (S9)

- [ ] `Private/Style/ConvertTo-BorderChars.ps1` lines 9-13: expand each border map entry to multiline format

---

## Verification Checklist

1. Run `Invoke-Pester ./Tests/ -Output Detailed | Out-File ./test-output.txt` after each phase — suite must stay green
2. After Phase 5: confirm new `$result -is [PSCustomObject]` assertion passes
3. After Phase 6: zero functional backtick continuations remaining
4. After all phases: `Import-Module ./PSTea.psd1 -Force` — no errors
