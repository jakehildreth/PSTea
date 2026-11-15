# Agent Instructions

## Issue tracking

Use GitHub Issues in `jakehildreth/PSTea`. Read `docs/agents/issue-tracker.md` before creating, claiming, updating, or closing issues. Check for duplicates before publishing new work.

Use the canonical triage labels in `docs/agents/triage-labels.md`.

## Domain context

Before exploring a domain area, follow `docs/agents/domain.md`: load the relevant `CONTEXT.md` and ADRs when present, and use their vocabulary.

## Repository layout

PSTea is a PowerShell implementation of The Elm Architecture. Public commands live in `Public/`, private helpers in `Private/`, Pester tests in `Tests/`, tutorials in `docs/tutorial/`, and architectural decisions in `docs/adr/`.

## Validation

Use the existing PowerShell/Pester tooling. Run the smallest targeted tests covering a change; use `Build/Build-Module.ps1` when full module validation is required.

## Shell safety

Use non-interactive flags for commands that may prompt: `cp -f`, `mv -f`, `rm -f`/`rm -rf`, `ssh -o BatchMode=yes`, `scp -o BatchMode=yes`, and `brew` with `HOMEBREW_NO_AUTO_UPDATE=1`.

## Session completion

1. File GitHub Issues for remaining work.
2. Run relevant quality gates for changed code.
3. Update related GitHub Issues with outcomes or blockers.
4. Report `git status` and any uncommitted changes.

Commit or push only when explicitly requested.
