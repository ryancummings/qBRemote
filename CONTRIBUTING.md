# Contributing

Thank you for helping improve Simple qBittorrent Remote.

## Before you start

Search the open issues before you report a bug or propose a feature. For a large behavior or interface change, open an issue before you write code.

Do not use a public issue for a security problem. Follow [SECURITY.md](SECURITY.md).

## Development setup

1. Install Xcode 26 or later.
2. Fork and clone the repository.
3. Open `qbremote.xcodeproj`.
4. Select the `qbremote` scheme and an iOS simulator.
5. Run the app.

Read [AGENTS.md](AGENTS.md) for module boundaries and test rules, and [CONTEXT.md](CONTEXT.md) for domain terms.

The app needs no build secret. Use demo mode if you do not have a qBittorrent server.

If you use a physical device, select your Apple development team. You can also change the bundle identifier for your local build.

Use deterministic transport responses to test real networking. Use injected memory credentials for session workflows and `SnapshotFixtures` for visual scenarios. Keep simulator signing enabled when running tests.

If concurrent simulator runners fail to launch, run the same test lane with one runner:

```sh
SCAN_PARALLEL_TESTING=false SCAN_MAX_CONCURRENT_SIMULATORS=1 SCAN_XCARGS='-jobs 2' fastlane test
```

## Pull requests

Keep each pull request focused on one change. Add tests for new behavior and bug fixes when practical.

Before you open the pull request:

1. Run `fastlane test`.
2. Run SwiftLint if your change modifies Swift source.
3. Run `fastlane snapshot_tests` if your change affects the interface.
4. Review the diff for credentials, server addresses, and generated files.
5. Explain the behavior change and the tests in the pull request.

The maintainer can ask for changes before merge. A contribution is available under the repository MIT License after merge.
