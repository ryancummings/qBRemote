# Security Policy

## Report a problem

Use GitHub private vulnerability reporting for a suspected security problem. Open the repository Security tab, select Advisories, and start a private report.

Do not include a credential, server address, session cookie, or exploit detail in a public issue.

Include the affected commit or app version, the impact, and the smallest reproduction that you can provide. The maintainer will acknowledge the report and discuss a disclosure plan with you.

## Supported versions

Security fixes target the current App Store version and the `main` branch. Older releases do not receive separate security updates.

## Scope

The app sends credentials and commands to a qBittorrent server that the user provides. A report is in scope when the app exposes secrets, bypasses its security configuration, or sends a different command from the one that the user selected.

Problems in qBittorrent itself are outside this repository. Report them to the qBittorrent project.
