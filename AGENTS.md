# AGENTS.md

This file gives coding agents the project rules that are not clear from the source tree.

## Project

Simple qBittorrent Remote is a SwiftUI client for qBittorrent Web API v2. The app has one iOS and iPadOS target. It has no backend and no third-party runtime dependencies.

The project uses Swift 6 with full data-race checking. The build sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES`. Types are main-actor isolated by default.

Start with these files:

- `qbremote/Views/RootView.swift` owns routing, onboarding, URL handling, demo wiring, and polling lifecycle.
- `qbremote/Services/QBServerSession.swift` owns the closed `QBOperation` catalog, authentication recovery, and connection status.
- `qbremote/Services/QBServerSessionFactory.swift` creates a session for each profile and tests unsaved connection values.
- `qbremote/Services/QBittorrentAPIService.swift` owns request construction, decoding, and `QBError`. `QBittorrentTransport.swift` supplies its transport.
- `qbremote/ViewModels/TorrentListViewModel.swift` owns refresh orchestration, polling, and torrent actions.
- `qbremote/ViewModels/ServerProfileDraft.swift` owns editable profile values, connection tests, and coordinated persistence.
- `qbremote/ViewModels/TorrentBrowsing.swift` owns in-memory criteria, derived results, and live filter options.

The network data flow is:

```text
SwiftUI view
  -> @Observable view model
    -> QBServerSession.run(QBOperation)
      -> QBittorrentAPIService -> QBittorrentTransport
      -> MockQBittorrentAPIService (demo)
```

## Agent skills

### Issue tracker

For issue, spec, and dependency operations, read [the issue tracker guide](docs/agents/issue-tracker.md).

### Triage labels

Before triage, read [the label policy](docs/agents/triage-labels.md), including how to provision missing labels.

### Domain docs

Before code exploration or domain-document changes, read [the domain guide](docs/agents/domain.md).

## Implementation rules

- Use `@Observable` final classes for view models.
- Use Swift concurrency and cancel long-lived tasks during teardown.
- Run workflow networking through typed sessions. Keep login, logout, and cookie mutation inside the session implementation and factory.
- Add each network capability to `QBOperation` and keep the operation protocol, production service, and demo adapter in sync.
- Keep each retryable operation to one API call. Polling, actions, and caller-owned side effects stay outside the session module.
- Obtain a session for the selected profile through `QBServerSessionFactory`. Keep sessions scoped to workflows rather than a global registry.
- Test profile drafts through the factory without reading or writing saved profiles or credentials. Persist only through explicit draft save.
- Preserve credential rollback on failed profile persistence and shared URL construction through `QBServerURL`.
- Keep browsing rules in `TorrentBrowsing`. Preserve search, status, sorting, and tag-match mode when changing servers.
- Reset category, tags, location, and tracker only on an actual server change or explicit clear. Polling must retain selected values that disappear.
- Send the `Referer` header and the manual `SID` cookie with authenticated requests.
- Keep `URLSession` cookie handling set to `.never` because the app owns cookie storage.
- Add network failure modes to `QBError` with user-facing descriptions.
- Put passwords and cookies in `KeychainService`, scoped by the profile UUID.
- Give every new SwiftData model property a default value.
- Mark decoded value models `nonisolated` and `Sendable` when they cross into detached decoding work.
- Put networking and SwiftData access in a view model or service, not in a view.
- Preserve iPhone and iPad navigation parity.
- Add no third-party runtime dependency without maintainer approval.

Keep these compatibility behaviors:

- The categories endpoint can return `[]` instead of `{}`.
- Login can return `Ok.` without an `SID` cookie.
- Unsupported or malformed tag responses can return an empty list. Authentication, transport, and cancellation errors must propagate.
- An explicit 401 or 403 starts one shared login and one retry. A second rejection fails without another retry.
- Transport and authentication failures fail connection status. Decoding and operation errors preserve connected status. Cancellation preserves the prior status.

## Tests

Run `fastlane test` after service or view-model changes. UI tests use `-isUITest YES` and usually `-isDemoMode YES` for deterministic data.

Use real service tests with deterministic transport responses for networking behavior. Inject `MemorySessionCredentials` through the factory for workflow tests.

Run simulator tests with signing enabled. Unsigned compile checks do not prove Keychain behavior.

Visual tests live in `qbremoteSnapshotTests`. Reference images use iOS 26.5, the `America/New_York` time zone, light and dark mode, and both device families. Run `fastlane snapshot_tests` for these simulator names:

- `qbremote-VisualTests-17Pro`
- `qbremote-VisualTests-iPadPro13`

Use `fastlane record_snapshots` only for an intentional UI change. Review every changed PNG, then run `fastlane snapshot_tests` again.

Seed snapshot view models from `SnapshotFixtures`. Use `MockQBittorrentAPIService(simulate: false)`. Keep suites inside `SnapshotSuite` because tests share UserDefaults and SwiftData containers.

Snapshot comparison uses `Diffing.lsbTolerantImage`. Change only `maxChannelDelta` and `allowedOutlierPixels` after you measure a stable renderer difference. Do not loosen these values to accept a visible UI change.

## Style

Match the existing `// MARK: -` sections and aligned switch cases. Avoid force unwraps. Follow `.swiftlint.yml`, including the `explicit_self` analyzer rule.

New Swift files under the synchronized Xcode groups need no manual project-file entry.
