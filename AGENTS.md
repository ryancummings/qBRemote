# AGENTS.md

This file defines implementation boundaries and test rules for coding agents.

## Project

Simple qBittorrent Remote is a SwiftUI client for qBittorrent Web API v2. The app has one iOS and iPadOS target. It has no backend and no third-party runtime dependencies.

The project uses Swift 6 concurrency checks. The build sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES`. By default, types run on the main actor.

Start with these files:

- `qbremote/Views/RootView.swift` chooses screens, handles incoming URLs, connects demo data, and starts or stops repeated refreshes.
- `qbremote/Services/QBServerSession.swift` defines the allowed `QBOperation` values and owns login recovery and connection status.
- `qbremote/Services/QBServerSessionFactory.swift` creates a session for each profile and tests unsaved connection values.
- `qbremote/Services/QBittorrentAPIService.swift` builds requests, decodes responses, and defines `QBError`. `QBittorrentTransport.swift` sends requests.
- `qbremote/ViewModels/TorrentListViewModel.swift` coordinates refreshes, schedules polling, and runs torrent actions. Polling means fetching updates at regular intervals.
- `qbremote/ViewModels/ServerProfileDraft.swift` edits profile values, tests connections, and saves profiles and credentials together.
- `qbremote/ViewModels/TorrentBrowsing.swift` applies search, filters, and sorting to the local torrent list.

The network data flow is:

```text
SwiftUI view
  -> @Observable view model
    -> QBServerSession.run(QBOperation)
      -> QBittorrentAPIService -> QBittorrentTransport
      -> MockQBittorrentAPIService (demo)
```

## Task guides

- Before issue, spec, or dependency work, read the [issue tracker guide](docs/agents/issue-tracker.md).
- Before triage, read the [label policy](docs/agents/triage-labels.md), including how to create missing labels.
- Before code exploration or domain-document changes, read the [domain guide](docs/agents/domain.md).

## Implementation rules

- Use `@Observable` final classes for view models.
- Use Swift concurrency. Cancel long-lived tasks when their owner is destroyed.
- Run network workflows through typed sessions. Keep login, logout, and cookie changes inside the session implementation and factory.
- Add each network capability to `QBOperation` and keep the operation protocol, production service, and demo adapter in sync.
- Keep each retryable operation to one API call. Keep refresh scheduling and action follow-up work outside the session module.
- Obtain a session for the selected profile through `QBServerSessionFactory`. Create sessions for each workflow. Do not use a global session registry.
- Test profile drafts through the factory without reading or writing saved profiles or credentials. Save only through the draft's explicit save action.
- If a profile save fails, restore the previous credentials. Build URLs through `QBServerURL` for saved profiles and connection tests.
- Keep browsing rules in `TorrentBrowsing`. Preserve search, status, sorting, and tag-match mode when changing servers.
- Reset category, tags, location, and tracker only on an actual server change or explicit clear. Polling must retain selected values that disappear.
- Send the `Referer` header and the manual `SID` cookie with authenticated requests.
- Keep `httpCookieAcceptPolicy` set to `.never` because the app owns cookie storage.
- Add network failure modes to `QBError` with user-facing descriptions.
- Put passwords and cookies in `KeychainService`, under the profile UUID.
- Give every new SwiftData model property a default value.
- Mark decoded value models `nonisolated` and `Sendable` when they cross into detached decoding work.
- Put networking and SwiftData access in a view model or service, not in a view.
- Keep the same actions available through iPhone and iPad navigation.
- Add no third-party runtime dependency without maintainer approval.

Keep these compatibility behaviors:

- The categories endpoint can return `[]` instead of `{}`.
- Login can return `Ok.` without an `SID` cookie.
- Unsupported or malformed tag responses can return an empty list. Authentication, transport, and cancellation errors must propagate.
- An explicit 401 or 403 starts one shared login and one retry. A second rejection fails without another retry.
- Transport and authentication failures set a failed connection status. Decoding and operation errors preserve the current status. Cancellation does not mark the connection as failed.

## Tests

Follow [Contributing](CONTRIBUTING.md#tests) for commands, simulator requirements, signing, and reference-image updates.
Run `fastlane test` after service or view-model changes.
UI tests use `-isUITest YES` and usually `-isDemoMode YES` for fixed demo data.

Test the real network service with fixed transport responses.
Inject `MemorySessionCredentials` through the factory for workflow tests.

Seed snapshot view models from `SnapshotFixtures`. Use `MockQBittorrentAPIService(simulate: false)`. Keep suites inside `SnapshotSuite` because tests share UserDefaults and SwiftData containers.

Snapshot comparison uses `Diffing.lsbTolerantImage`. Change only `maxChannelDelta` and `allowedOutlierPixels` after you measure a stable renderer difference. Do not loosen these values to accept a visible UI change.

## Style

Match the existing `// MARK: -` sections and aligned switch cases. Handle optional values without force unwraps. Follow `.swiftlint.yml`, including the `explicit_self` analyzer rule.

New Swift files under the synchronized Xcode groups need no manual project-file entry.
