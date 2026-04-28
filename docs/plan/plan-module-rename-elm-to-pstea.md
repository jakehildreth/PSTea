# Plan: Rename Module from Elm to PSTea

## Status: In Progress

## Rationale

The module was named "Elm" because it implements The Elm Architecture (TEA). Elm is a
programming language. This module replicates the architecture - it is not the language.
Naming it "Elm" misrepresents the relationship. See ADR-025 for full decision record.

## Naming Decisions

| Concern | Decision |
|---------|----------|
| Module name | `PSTea` |
| Module files | `PSTea.psd1`, `PSTea.psm1` |
| Command prefix | `Tea` |
| Public functions | `New-TeaBox`, `Start-TeaProgram`, etc. |
| Private functions | Same `Tea` prefix |
| Debug log | `/tmp/pstea-web-debug.log` |
| C# helper type | `TeaConsoleHelper` |
| Default web title | `'PSTea TUI'` |
| Stub `New-Elm` | Deleted (dead code) |
| Existing ADRs/plan | Left as-is (historical records) |

## Phase 0 - Documentation (do first)

- [x] Create `docs/adr/ADR-025-module-rename-elm-to-pstea.md`
- [x] Create `docs/plan/plan-module-rename-elm-to-pstea.md` (this file)

## Phase 1 - Module Root

- [ ] Rename `Elm.psd1` -> `PSTea.psd1`; update `RootModule = 'PSTea.psm1'`; update `Description`
- [ ] Rename `Elm.psm1` -> `PSTea.psm1`

## Phase 2 - Public Source Files

All files in `Public/` - rename file, rename function inside.

| Old file | New file | Function |
|----------|----------|----------|
| `Public/New-Elm.ps1` | DELETED | — |
| `Public/Runtime/Start-ElmProgram.ps1` | `Start-TeaProgram.ps1` | `Start-TeaProgram` |
| `Public/Runtime/Start-ElmWebServer.ps1` | `Start-TeaWebServer.ps1` | `Start-TeaWebServer` |
| `Public/View/New-ElmBox.ps1` | `New-TeaBox.ps1` | `New-TeaBox` |
| `Public/View/New-ElmText.ps1` | `New-TeaText.ps1` | `New-TeaText` |
| `Public/View/New-ElmRow.ps1` | `New-TeaRow.ps1` | `New-TeaRow` |
| `Public/View/New-ElmPaginator.ps1` | `New-TeaPaginator.ps1` | `New-TeaPaginator` |
| `Public/View/New-ElmTextInput.ps1` | `New-TeaTextInput.ps1` | `New-TeaTextInput` |
| `Public/View/New-ElmTextarea.ps1` | `New-TeaTextarea.ps1` | `New-TeaTextarea` |
| `Public/View/New-ElmComponent.ps1` | `New-TeaComponent.ps1` | `New-TeaComponent` |
| `Public/View/New-ElmComponentMsg.ps1` | `New-TeaComponentMsg.ps1` | `New-TeaComponentMsg` |
| `Public/View/New-ElmSpinner.ps1` | `New-TeaSpinner.ps1` | `New-TeaSpinner` |
| `Public/View/New-ElmProgressBar.ps1` | `New-TeaProgressBar.ps1` | `New-TeaProgressBar` |
| `Public/View/New-ElmList.ps1` | `New-TeaList.ps1` | `New-TeaList` |
| `Public/View/New-ElmTable.ps1` | `New-TeaTable.ps1` | `New-TeaTable` |
| `Public/View/New-ElmViewport.ps1` | `New-TeaViewport.ps1` | `New-TeaViewport` |
| `Public/Style/New-ElmStyle.ps1` | `New-TeaStyle.ps1` | `New-TeaStyle` |
| `Public/Subscriptions/New-ElmKeySub.ps1` | `New-TeaKeySub.ps1` | `New-TeaKeySub` |
| `Public/Subscriptions/New-ElmTimerSub.ps1` | `New-TeaTimerSub.ps1` | `New-TeaTimerSub` |
| `Public/Drivers/New-ElmTerminalDriver.ps1` | `New-TeaTerminalDriver.ps1` | `New-TeaTerminalDriver` |
| `Public/Drivers/New-ElmWebSocketDriver.ps1` | `New-TeaWebSocketDriver.ps1` | `New-TeaWebSocketDriver` |

## Phase 3 - Private Source Files

Files to rename + update content:

| Old file | New file | Notes |
|----------|----------|-------|
| `Private/Core/Copy-ElmModel.ps1` | `Copy-TeaModel.ps1` | also: `Copy-ElmModelValue` -> `Copy-TeaModelValue` |
| `Private/Drivers/Invoke-ElmWebSocketListener.ps1` | `Invoke-TeaWebSocketListener.ps1` | `Write-ElmWebDebug` -> `Write-TeaWebDebug`; `$script:ElmWebDebugLog` -> `$script:TeaWebDebugLog`; `/tmp/elm-web-debug.log` -> `/tmp/pstea-web-debug.log` |
| `Private/Drivers/Invoke-ElmDriverLoop.ps1` | `Invoke-TeaDriverLoop.ps1` | |
| `Private/Rendering/Measure-ElmViewTree.ps1` | `Measure-TeaViewTree.ps1` | also: `Invoke-ElmPass1/2` -> `Invoke-TeaPass1/2`; `Resolve-ElmDimension` -> `Resolve-TeaDimension` |
| `Private/Rendering/Compare-ElmViewTree.ps1` | `Compare-TeaViewTree.ps1` | |
| `Private/Rendering/Apply-ElmStyle.ps1` | `Apply-TeaStyle.ps1` | calls `Resolve-TeaColor`, `ConvertTo-BorderChars` |
| `Private/Runtime/Invoke-ElmEventLoop.ps1` | `Invoke-TeaEventLoop.ps1` | update all internal call sites |
| `Private/Runtime/Invoke-ElmUpdate.ps1` | `Invoke-TeaUpdate.ps1` | calls `Copy-TeaModel` |
| `Private/Runtime/Invoke-ElmView.ps1` | `Invoke-TeaView.ps1` | |
| `Private/Style/Resolve-ElmColor.ps1` | `Resolve-TeaColor.ps1` | |
| `Private/Subscriptions/Invoke-ElmSubscriptions.ps1` | `Invoke-TeaSubscriptions.ps1` | |
| `Private/Subscriptions/ConvertFrom-ElmKeyString.ps1` | `ConvertFrom-TeaKeyString.ps1` | |
| `Private/Web/Get-ElmXtermPage.ps1` | `Get-TeaXtermPage.ps1` | default title `'Elm TUI'` -> `'PSTea TUI'` |

Content-only updates (no file rename):

| File | Change |
|------|--------|
| `Private/Rendering/ConvertTo-AnsiOutput.ps1` | `Apply-ElmStyle` -> `Apply-TeaStyle` |
| `Private/Rendering/ConvertTo-AnsiPatch.ps1` | `Apply-ElmStyle` -> `Apply-TeaStyle` |
| `Private/Rendering/Enable-VirtualTerminal.ps1` | `ElmConsoleHelper` -> `TeaConsoleHelper` |
| `Public/Runtime/Start-TeaWebServer.ps1` (after rename) | `/tmp/elm-web-debug.log` -> `/tmp/pstea-web-debug.log` |

## Phase 4 - Test Files

All `Tests/*Elm*.Tests.ps1` files: rename, update dot-source paths, update all function calls.

Pattern: `*-ElmFoo.Tests.ps1` -> `*-TeaFoo.Tests.ps1`

Special cases:
- `Enable-VirtualTerminal.Tests.ps1` (no rename): `'ElmConsoleHelper'` -> `'TeaConsoleHelper'`
- `Get-TeaXtermPage.Tests.ps1` (renamed): `'Elm TUI'` -> `'PSTea TUI'`

## Phase 5 - Example Scripts

No file renames. Content updates only:

- `Import-Module "$PSScriptRoot/../Elm.psd1"` -> `"$PSScriptRoot/../PSTea.psd1"`
- All `New-Elm*`, `Start-Elm*`, `Invoke-Elm*` calls -> `New-Tea*`, `Start-Tea*`, `Invoke-Tea*`

## Phase 6 - README

Update module name and any usage examples.

## Verification

1. `Import-Module ./PSTea.psd1 -Force` - loads without error
2. `Get-Command -Module PSTea | Select-Object Name | Sort-Object Name` - no `Elm` names
3. Run pester suite; write output to file then read results
4. `grep -r 'Elm' ./Public ./Private ./Tests ./Examples --include='*.ps1'` - zero hits
