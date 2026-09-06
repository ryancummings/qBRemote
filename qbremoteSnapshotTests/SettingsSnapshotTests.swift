//
//  SettingsSnapshotTests.swift
//  qbremoteSnapshotTests
//
//  Note: the About section renders the marketing version from the bundle, so
//  these references need re-recording after a version bump — an intentional,
//  visible change.
//

import SnapshotTesting
import SwiftUI
import Testing

@testable import qbremote

extension SnapshotSuite {

    @MainActor
    @Suite
    struct SettingsSnapshotTests {

        @Test("Settings")
        func settings() {
            SnapshotEnvironment.pinUserDefaults()
            assertScreenSnapshot(
                NavigationStack { SettingsView() },
                devices: [SnapshotEnvironment.primaryDevice]
            )
        }
    }
}
