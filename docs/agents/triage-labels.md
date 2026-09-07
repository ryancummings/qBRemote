# Triage labels

Use these labels to describe the next step for an issue.
The table defines the policy. It does not list which labels already exist on GitHub.

| Role and label | Meaning |
| --- | --- |
| `needs-triage` | A maintainer needs to assess the issue. |
| `needs-info` | The reporter needs to provide more information. |
| `ready-for-agent` | The issue has enough detail for an agent to implement it. |
| `ready-for-human` | A human needs to implement the change. |
| `wontfix` | The project will not make the change. |

Before applying a label, run `gh label list --limit 100`.
If a required label is missing, create it with the exact name and meaning above.
Then apply it to the issue. A missing label does not change the issue's state.
