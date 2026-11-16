# Issue tracker: GitHub Issues

Issues for this repository live at <https://github.com/jakehildreth/PSTea/issues>. Use the GitHub CLI for routine operations.

## Workflow

```bash
gh issue list --repo jakehildreth/PSTea --state open
gh issue view <number> --repo jakehildreth/PSTea
gh issue create --repo jakehildreth/PSTea --title "..." --body-file <file>
gh issue edit <number> --repo jakehildreth/PSTea --add-assignee @me
gh issue comment <number> --repo jakehildreth/PSTea --body-file <file>
gh issue close <number> --repo jakehildreth/PSTea --comment "..."
```

Search open and closed issues before creating one. Claim work by assigning the issue to yourself. Record durable findings in issue comments, then close the issue when its completion criteria are met.

## Pull requests as a triage surface

External pull requests are code contributions, not feature-request substitutes. If a pull request exposes separate follow-up work, publish that work as a GitHub Issue.

## Skill terminology

- **Publish to the issue tracker:** create a GitHub Issue.
- **Fetch the relevant ticket:** use `gh issue view`.
- **Apply a triage role:** use the label mapped in `docs/agents/triage-labels.md`.

## Wayfinding operations

- **Map:** a GitHub Issue labelled `wayfinder:map`.
- **Child ticket:** a GitHub sub-issue of the map with one `wayfinder:<type>` label.
- **Blocking:** GitHub's native issue dependency relationship.
- **Frontier:** open, unblocked, unassigned sub-issues of the map.
- **Claim:** assign the issue to yourself before starting.
- **Resolve:** post the decision as a comment, close the ticket, and append its linked gist to the map's Decisions-so-far section.

Create missing `wayfinder:*` labels when first needed, following the Wayfinder skill's canonical names.
