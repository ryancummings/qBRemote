# Contributing

Search the open issues before you report a bug or propose a feature.
For a large behavior or interface change, open an issue before you write code.
For security problems, follow [SECURITY.md](SECURITY.md).

## Development setup

Follow [Build from source](README.md#build-from-source) to open and run the app.
The app needs no build secrets. Use [demo mode](README.md#try-demo-mode) if you do not have a server.

Read [AGENTS.md](AGENTS.md) for implementation rules and [CONTEXT.md](CONTEXT.md) for project terms.

## Tests

Install the command-line tools:

```sh
brew install fastlane xcbeautify swiftlint
```

Run commands from the repository root.
The [Fastfile](fastlane/Fastfile) defines these lanes, which are named Fastlane commands:

| Command | Purpose |
| --- | --- |
| `fastlane test` | Run unit and UI tests in the `qbremote` scheme. |
| `fastlane snapshot_tests` | Compare screens with saved reference images on iPhone and iPad simulators. |
| `fastlane record_snapshots` | Replace all reference images after an intentional UI change. |

You can also run the `qbremote` test action in Xcode.
Keep simulator signing enabled. Unsigned builds do not prove that Keychain access works.

If parallel simulator tests fail to launch, use one runner:

```sh
SCAN_PARALLEL_TESTING=false SCAN_MAX_CONCURRENT_SIMULATORS=1 SCAN_XCARGS='-jobs 2' fastlane test
```

### Visual tests

Install the iOS 26.5 simulator runtime in Xcode before running visual tests.
Use the `America/New_York` time zone on the Mac that runs them.
The date rows use the simulator's time zone. The lane does not set it for you.

The visual test lanes create these simulators when they are missing:

- `qbremote-VisualTests-17Pro`
- `qbremote-VisualTests-iPadPro13`

The tests render iPhone and iPad screen sizes in light and dark mode.
Keep both simulator runs because some layouts depend on the host device family.

Use `fastlane record_snapshots` only when the intended interface changes.
This command deletes the entire `qbremoteSnapshotTests/__Snapshots__` directory before it records replacements.
It continues after test failures, so its exit status alone does not prove success.
Review the output and every changed PNG, then run `fastlane snapshot_tests`.

Read the [snapshot rules](AGENTS.md#tests) before changing fixtures or image comparison limits.

## Pull requests

Keep each pull request focused on one change.
Add tests for new behavior and bug fixes when practical.
Use these checks for the files you change:

| Change | Required checks |
| --- | --- |
| App code or test code | Run `fastlane test`. |
| Swift source | Run `swiftlint lint`. |
| App interface | Also run `fastlane snapshot_tests`. |
| Documentation only | Make sure that links, commands, and claims match the source. Review the rendered Markdown. |

Before submission, remove secrets, private server data, and unrelated generated files from the diff.
Review every changed reference image. Demo torrent names in test fixtures can remain.
Describe the change, its reason, and the checks in the pull request.

The maintainer can ask for changes before merge.
Contributions use the repository's [MIT License](LICENSE).
