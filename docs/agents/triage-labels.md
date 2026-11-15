# Triage labels

Use these canonical GitHub Issue labels without translating them:

| Label | Meaning |
| --- | --- |
| `needs-triage` | Maintainer needs to evaluate this issue |
| `needs-info` | Waiting on the reporter for more information |
| `ready-for-agent` | Fully specified and ready for an autonomous agent |
| `ready-for-human` | Requires human implementation or input |
| `wontfix` | Will not be actioned |

Apply labels with:

```bash
gh issue edit <number> --repo jakehildreth/PSTea --add-label <label>
```
