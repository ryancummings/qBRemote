//
//  OnboardingSnapshotTests.swift
//  qbremoteSnapshotTests
//

import SnapshotTesting
import SwiftData
import SwiftUI
import Testing

@testable import qbremote

extension SnapshotSuite {

    @MainActor
    @Suite
    struct OnboardingSnapshotTests {

        @Test("Onboarding — no server configured")
        func onboarding() throws {
            // Empty profile store + demo mode off routes RootView to the
            // onboarding screen; pinned defaults keep the tip-jar popup and
            // launch counter out of the picture.
            SnapshotEnvironment.pinUserDefaults()
            assertScreenSnapshot(
                RootView()
                    .modelContainer(SnapshotFixtures.emptyContainer)
            )
        }
    }
}
