# Issue tracker: GitHub

Issues and specs for this repo live as GitHub issues. Use the `gh` CLI for all operations.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`
- **Read an issue**: `gh issue view <number> --comments`, including labels.
- **List issues**: use `gh issue list` with the appropriate state, labels, and JSON fields.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **Apply or remove labels**: `gh issue edit <number> --add-label "..."` or `--remove-label "..."`
- **Close an issue**: `gh issue close <number> --comment "..."`

Infer `huddlz-hq/huddlz` from the Git remote; `gh` does this automatically inside the clone.

## Pull requests as a triage surface

**PRs as a request surface: no.**

GitHub shares one number space across issues and pull requests. Resolve an ambiguous `#42` by checking the pull request first and falling back to the issue.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`.

## Wayfinding operations

A wayfinding map is one GitHub issue with linked child issues.

- Label the map `wayfinder:map`.
- Link child tickets using GitHub sub-issues when available.
- Label children `wayfinder:<type>`.
- Represent blocking with native GitHub issue dependencies when available.
- Fall back to `Blocked by: #<n>` when native dependencies are unavailable.
- Claim work by assigning the issue to the current developer.
- Resolve work by recording the answer, closing the child, and updating the map.
