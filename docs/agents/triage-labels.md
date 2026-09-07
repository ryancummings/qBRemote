# Triage Labels

This policy maps five canonical triage roles to label names. It is a naming policy, not an inventory of labels already present on GitHub.

| Canonical role | Label in our tracker | Meaning                                  |
| -------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`             | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`               | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent`          | `ready-for-agent`    | Fully specified, ready for an agent  |
| `ready-for-human`          | `ready-for-human`    | Requires human implementation            |
| `wontfix`                  | `wontfix`            | Will not be actioned                     |

When a skill mentions a role, use the corresponding label string from this table.

Before applying a label, inspect `gh label list --limit 100`. If a policy label is missing, create it with the exact name and meaning above before applying it. Create labels as needed rather than treating a missing label as a different triage state.
