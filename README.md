# Simple qBittorrent Remote

Simple qBittorrent Remote is a native SwiftUI client for the qBittorrent Web API. It runs on iPhone and iPad.

The app connects to a qBittorrent server that you control. It does not download torrent data to the iOS device.

This project is independent. It is not affiliated with or endorsed by the qBittorrent project.

## Features

- Connect to multiple qBittorrent servers.
- Add magnet links, torrent URLs, and `.torrent` files.
- Pause, resume, delete, move, categorize, and tag torrents.
- Search, filter, and sort the torrent list.
- View transfer rates, progress, files, trackers, and peers.
- Change selected qBittorrent server preferences.
- Store passwords and session cookies in the iOS Keychain.
- Use demo mode without a qBittorrent server.

## Requirements

- macOS with Xcode 26 or later.
- iOS or iPadOS 26.1 or later.
- A qBittorrent server with the Web UI enabled.

The app target has no third-party runtime dependencies. The snapshot-test target uses `swift-snapshot-testing`.

## Run the app

```sh
git clone https://github.com/ryancummings/qbRemote.git
cd qBRemote
open qbremote.xcodeproj
```

Select the `qbremote` scheme and an iOS simulator. Then run the app.

If you run the app on a physical device, select your development team in Xcode. Use a unique bundle identifier if your Apple account does not own `com.OneRadStudio.qbremote`.

On first launch, add the address and credentials for your qBittorrent server. You can enable demo mode in Settings if you do not have a server available.

## Security notes

The app stores each server password and session cookie in the iOS Keychain. It does not store these values in SwiftData or UserDefaults.

Plain HTTP is available because many qBittorrent servers run on a private network. HTTP does not protect credentials or traffic from other devices on that network. Use HTTPS or a trusted private network.

Support for an untrusted TLS certificate is disabled by default. You must enable it for each server profile.

Read [SECURITY.md](SECURITY.md) before you report a security problem.

## Architecture

The app uses SwiftUI, SwiftData, Observation, `URLSession`, and Swift concurrency. It uses a small MVVM structure:

```text
View
  -> @Observable view model
    -> QBittorrentAPIServiceProtocol
      -> live API service or deterministic mock service
```

`ServerProfile` stores non-secret server configuration. `KeychainService` stores secrets for each profile UUID. `TorrentListViewModel` owns the polling loop and retries authentication after an expired session.

## Tests

Install Fastlane and `xcbeautify` if you want to use the command-line lanes:

```sh
brew install fastlane xcbeautify
fastlane test
```

You can also run the `qbremote` test action in Xcode.

Visual snapshot tests use reference images from the iOS 26.5 simulator runtime. The command creates its named iPhone and iPad simulators when needed:

```sh
fastlane snapshot_tests
```

The required simulator names and image comparison rules are in [AGENTS.md](AGENTS.md).

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before you open a pull request. Use GitHub Issues for confirmed bugs and focused feature requests.

## License

Copyright 2026 Ryan Cummings.

This project is available under the [MIT License](LICENSE).
