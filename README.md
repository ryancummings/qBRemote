<p align="center">
  <img src="qbremote/Assets.xcassets/AppIcon.appiconset/qbremote.png" width="100" height="100" alt="Simple qBittorrent Remote app icon">
</p>

<h1 align="center">Simple qBittorrent Remote</h1>

<p align="center">
  Manage your qBittorrent server from your phone or tablet.<br>
  A native SwiftUI app for iPhone and iPad, licensed under MIT.
</p>

<p align="center">
  <a href="https://apps.apple.com/app/id6760194789">
    <img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" height="48" alt="Download on the App Store">
  </a>
</p>

<p align="center">
  <a href="#screenshots">Screenshots</a> ·
  <a href="#features">Features</a> ·
  <a href="#build-from-source">Build from source</a> ·
  <a href="SUPPORT.md">Support</a> ·
  <a href="CONTRIBUTING.md">Contribute</a>
</p>

Manage downloads, add torrents, and switch between servers without opening the Web UI.
Your files stay on your computer or network storage device (NAS).
The app controls your qBittorrent server. It does not download torrent data to your iPhone or iPad.

## Screenshots

<p align="center">
  <img src="qbremoteSnapshotTests/__Snapshots__/TorrentListSnapshotTests/torrentListPopulated.iPhone17Pro-light.png" width="30%" alt="iPhone torrent list in light mode with download progress, transfer speeds, search, and status filters">
  &nbsp;
  <img src="qbremoteSnapshotTests/__Snapshots__/TorrentDetailSnapshotTests/torrentDetailDownloading.iPhone17Pro-dark.png" width="30%" alt="iPhone torrent details in dark mode with transfer statistics and pause, category, tag, move, and delete actions">
  &nbsp;
  <img src="qbremoteSnapshotTests/__Snapshots__/ServerScreensSnapshotTests/serverListPopulated.iPhone17Pro-light.png" width="30%" alt="iPhone server picker with multiple saved server profiles and connection status">
</p>

<p align="center">Track downloads · Inspect torrent details · Switch servers</p>

<details>
  <summary>See the iPad layout</summary>
  <p align="center">
    <img src="qbremoteSnapshotTests/__Snapshots__/TorrentListSnapshotTests/torrentListPopulated.iPadPro13-light.png" width="640" alt="iPad torrent list with search, status filters, and transfer statistics across the wider display">
  </p>
</details>

Screenshots show demo data from the repository's visual tests. The App Store version can differ from the current source.

## Features

- Connect to multiple qBittorrent servers.
- Add magnet links, torrent URLs, and `.torrent` files.
- Pause, resume, delete, move, categorize, and tag torrents.
- Search, filter, and sort the torrent list.
- View transfer rates, progress, tracker details, and peer counts.
- Change selected qBittorrent server preferences.
- Store passwords and session cookies in the iOS Keychain.
- Use demo mode without a qBittorrent server.

## Get started

The app requires iOS or iPadOS 26.1 or later.
Use qBittorrent 5.0 or later with its Web UI enabled.
The app uses the [qBittorrent 5.0 API](https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-%28qBittorrent-5.0%29), including its start and stop commands.

1. [Download the app from the App Store](https://apps.apple.com/app/id6760194789).
2. Enable the Web UI on your qBittorrent server.
3. In the app, tap Add Server.
4. Enter the host, port, username, and password.
5. Tap Save.

Enter the host without `http://` or `https://`. Use the HTTPS switch to choose the protocol.
Test Connection tests the values without saving them. You can save without running the test.

### Try demo mode

1. Open Settings. On the first-launch screen, tap the gear button.
2. Under About, tap Version five times to reveal Demo Mode.
3. Turn on Demo Mode.

Demo mode uses sample data and needs no server.

## Build from source

You need macOS with Xcode 26.1 or later. The app target has no third-party runtime dependencies.
The snapshot-test target uses `swift-snapshot-testing`.
If GitHub shows a 404 page, sign in with an account that has repository access.

```sh
git clone https://github.com/ryancummings/qBRemote.git
cd qBRemote
open qbremote.xcodeproj
```

Select the `qbremote` scheme and an iOS simulator. Then run the app.

If you run the app on a physical device, select your development team in Xcode. If your Apple account does not own `com.OneRadStudio.qbremote`, use a unique bundle identifier.

## Security notes

The app stores each server password and session cookie in the iOS Keychain. It does not store these values in SwiftData or UserDefaults.

Plain HTTP is available because many qBittorrent servers run on a private network. HTTP does not protect credentials or traffic from other devices on that network. Use HTTPS or a trusted private network.

Support for an untrusted TLS certificate is disabled by default. You must enable it for each server profile.

Read [SECURITY.md](SECURITY.md) before you report a security problem.

## Architecture

The app uses SwiftUI, SwiftData, Observation, `URLSession`, and Swift concurrency. Network workflows use typed server sessions:

```text
View
  -> @Observable view model
    -> QBServerSession.run(QBOperation)
      -> production API service -> URLSession or test transport
      -> demo adapter
```

A server session controls access to one saved server profile.
It restores cookies, shares login attempts, and retries a rejected request once.
`TorrentListViewModel` schedules repeated refreshes and runs torrent actions.
Files opened from another app can target a different profile without changing the active server.

`ServerProfile` stores configuration without secrets. `KeychainService` stores passwords and cookies under each profile's unique ID.
`ServerProfileDraft` tests unsaved values and saves changes only when requested.
If a save fails, it restores the previous profile values and credentials.

`TorrentBrowsing` applies search, filters, and sorting to the latest torrent list.
Server switches preserve search, status, sorting, and the tag-match mode.
They clear category, tag, location, and tracker selections.
Repeated refreshes retain selected values even when they disappear from the list. These choices stay in memory only.

Read the [domain glossary](CONTEXT.md) and [typed-session decision](docs/adr/0001-use-typed-operations-for-server-sessions.md) for the design terms and reasoning.
The [implementation rules](AGENTS.md) describe the boundaries that contributions must preserve.

## Tests

See [Contributing](CONTRIBUTING.md#tests) for test commands, simulator requirements, and reference-image updates.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before you open a pull request. Use GitHub Issues for confirmed bugs and focused feature requests.

## License

Copyright 2026 Ryan Cummings.

This project is available under the [MIT License](LICENSE).

This project is independent. It is not affiliated with or endorsed by the qBittorrent project.
