# AGENTS.md

This file gives coding agents the project rules that are not clear from the source tree.

## Project

Simple qBittorrent Remote is a SwiftUI client for qBittorrent Web API v2. The app has one iOS and iPadOS target. It has no backend and no third-party runtime dependencies.

The project uses Swift 6 with full data-race checking. The build sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES`. Types are main-actor isolated by default.

Start with these files:

- `qbremote/Views/RootView.swift` owns routing, onboarding, URL handling, demo wiring, and polling lifecycle.
- `qbremote/Services/QBittorrentAPIService.swift` owns network calls and `QBError`.
- `qbremote/Services/QBittorrentAPIServiceProtocol.swift` is the dependency injection boundary.
- `qbremote/ViewModels/TorrentListViewModel.swift` owns list state, polling, and reauthentication.

The main data flow is:

```text
SwiftUI view
  -> @Observable view model
    -> QBittorrentAPIServiceProtocol
      -> QBittorrentAPIService or MockQBittorrentAPIService
```

## Implementation rules

- Use `@Observable` final classes for view models.
- Use Swift concurrency and cancel long-lived tasks during teardown.
- Keep `QBittorrentAPIServiceProtocol`, `QBittorrentAPIService`, and `MockQBittorrentAPIService` in sync.
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
- The tags endpoint can fail and return an empty list.
- A 401 or 403 response starts one login and retry cycle.

## Tests

Run `fastlane test` after service or view-model changes. UI tests use `-isUITest YES` and usually `-isDemoMode YES` for deterministic data.

Visual tests live in `qbremoteSnapshotTests`. Reference images use iOS 26.5, the `America/New_York` time zone, light and dark mode, and both device families. Run `fastlane snapshot_tests` for these simulator names:

- `qbremote-VisualTests-17Pro`
- `qbremote-VisualTests-iPadPro13`

Use `fastlane record_snapshots` only for an intentional UI change. Review every changed PNG, then run `fastlane snapshot_tests` again.

Seed snapshot view models from `SnapshotFixtures`. Use `MockQBittorrentAPIService(simulate: false)`. Keep suites inside `SnapshotSuite` because tests share UserDefaults and SwiftData containers.

Snapshot comparison uses `Diffing.lsbTolerantImage`. Change only `maxChannelDelta` and `allowedOutlierPixels` after you measure a stable renderer difference. Do not loosen these values to accept a visible UI change.

## Style

Match the existing `// MARK: -` sections and aligned switch cases. Avoid force unwraps. Follow `.swiftlint.yml`, including the `explicit_self` analyzer rule.

New Swift files under the synchronized Xcode groups need no manual project-file entry.
