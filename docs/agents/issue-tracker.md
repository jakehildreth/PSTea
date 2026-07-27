# Issue tracker: Beads

Issues for this repo live in the Beads database under `.beads/`. Beads is a CLI-first, AI-native issue tracker backed by Dolt. Use the `bd` CLI for all operations.

## Conventions

- **Find work**: `bd ready` lists issues with no blockers.
- **Read an issue**: `bd show <id>` shows full details, dependencies, and comments.
- **List issues**: `bd list --status=open`, optionally `--json` for structured output.
- **Create an issue**: `bd create --title "..." --description "..." --type task|bug|feature|chore|epic|decision|spike|story|milestone --priority 0-4`.
  - Priority: `0`/`P0` = critical, `4`/`P4` = backlog. Use numeric/P-form, not "high"/"medium"/"low".
  - Avoid `bd edit` — it opens `$EDITOR`. Prefer inline flags or `bd update`.
- **Claim work**: `bd update <id> --claim`.
- **Close an issue**: `bd close <id>` (or `bd close <id1> <id2> ...` for multiple).
- **Dependencies**: `bd dep add <issue> <depends-on>`; `bd blocked` shows stuck issues.
- **Comments / notes**: `bd note <id> <text>` or `bd comment add <id> <text>`.
- **Labels**: `bd label add <id> <label>` / `bd label remove <id> <label>`.
- **Search**: `bd search <query>` for keyword search.
- **Sync**: `bd dolt push` pushes beads data to the Dolt remote.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature requests; `/triage` reads this flag.)_

This repo uses Beads for issue tracking. External PRs are not currently routed through the Beads triage workflow.

## When a skill says "publish to the issue tracker"

Create a Beads issue with `bd create`.

## When a skill says "fetch the relevant ticket"

Run `bd show <id>`.

## Wayfinding operations

Used by `/wayfinder`.

- **Map**: a single Beads issue of type `epic` or `decision` acting as the parent/anchor.
- **Child ticket**: a Beads issue linked to the map via `bd dep add <child> <map>` or `--parent=<map>` on creation.
- **Blocking**: `bd dep add <blocked-issue> <blocker>`; a ticket is unblocked when every blocker is closed.
- **Frontier query**: `bd ready` scoped to children of the map.
- **Claim**: `bd update <id> --claim`.
- **Resolve**: add a closing note (`bd note <id> "..."`) then `bd close <id>`, and append a context pointer to the map issue's notes.
