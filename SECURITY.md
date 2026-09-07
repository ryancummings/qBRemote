# Security policy

## Report a problem

Email suspected security problems to [support@rads.icu](mailto:support@rads.icu).
Use “Simple qBittorrent Remote security report” as the subject.
The maintainer will acknowledge the report and discuss when to publish the details with you.

Include these details:

- Affected app version or commit
- Steps that show the problem
- Impact on the user or their data

Do not put passwords, private server addresses, session cookies, or exploit details in a public issue.

## Supported versions

Security fixes target the current App Store version and the `main` branch.
Older releases do not receive separate security updates.

## Scope

The app sends login details and commands to the user's qBittorrent server.
Report problems where the app exposes secrets, ignores its security configuration, or sends a command that the user did not select.

Report problems in qBittorrent itself to the [qBittorrent project](https://github.com/qbittorrent/qBittorrent).
