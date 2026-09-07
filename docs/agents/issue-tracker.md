# Issue tracker: GitHub

Use GitHub Issues for repository bugs, feature requests, and specs.
Follow global project guidance for private task tracking.
Run `gh` from this checkout so it selects the repository from the Git remote.

## Read issues and pull requests

Read an issue and its comments:

```sh
gh issue view <number> --comments
```

For structured output that includes labels, use:

```sh
gh issue view <number> --json number,title,body,labels,comments
```

List open issues with their labels:

```sh
gh issue list --state open --limit 100 --json number,title,labels
```

Use `--label` or `--state` to narrow the list.
Use `--json` with `--jq` when you need to filter output.

GitHub shares issue and pull request numbers.
For a pull request, use `gh pr view <number> --comments` and `gh pr diff <number>`.
If the item type is unknown, try `gh pr view <number>` first, then `gh issue view <number>`.

## Write to the tracker

When an authorized task says “publish to the issue tracker,” create a GitHub issue.
When it says “fetch the relevant ticket,” read the issue and its comments.

For issue bodies and comments, write the exact Markdown to a temporary file.
Pass that file with `--body-file` so newlines and shell characters remain intact.

| Action | Command |
| --- | --- |
| Create an issue | `gh issue create --title "..." --body-file <path>` |
| Add a comment | `gh issue comment <number> --body-file <path>` |
| Add a label | `gh issue edit <number> --add-label "..."` |
| Remove a label | `gh issue edit <number> --remove-label "..."` |
| Close an issue | `gh issue close <number>` |

Read the [label policy](triage-labels.md) before triage.

## Pull requests as feature requests

**PRs as a request surface: no.**

The `triage` skill reads this flag. Triage feature requests as issues, and review pull requests as proposed code changes.

## Wayfinder tasks

The `wayfinder` skill uses one parent issue, called a map, and linked child issues.
Use these conventions when that skill is active:

| Item | Convention |
| --- | --- |
| Map | Use `wayfinder:map`. Keep the Notes, Decisions-so-far, and Fog sections expected by the skill. |
| Child | Link it as a GitHub sub-issue. Use `wayfinder:research`, `wayfinder:prototype`, `wayfinder:grilling`, or `wayfinder:task`. |
| Fallback link | If sub-issues are unavailable, add a task-list link in the map and `Part of #<map>` in the child. |
| Blocker | Use GitHub issue dependencies. If unavailable, add `Blocked by: #<number>` to the child. |
| Next task | Take the first open child in map order with no open blocker and no assignee. |
| Claim | Run `gh issue edit <number> --add-assignee @me`. |
| Finish | Comment with the result, close the child, and link the result from the map's Decisions-so-far section. |

Create missing Wayfinder labels before applying them.
For a native dependency, use the blocker's numeric database ID, not its issue number:

```sh
gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>
```
