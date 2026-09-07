//
//  ServerScreensSnapshotTests.swift
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
    struct ServerScreensSnapshotTests {

        @Test("Server list — populated")
        func serverListPopulated() throws {
            SnapshotEnvironment.pinUserDefaults()
            assertScreenSnapshot(
                NavigationStack {
                    ServerListView(
                        profilesVM: SnapshotFixtures.profilesViewModel(),
                        isShowingAddServer: .constant(false)
                    )
                }
                .modelContainer(SnapshotFixtures.populatedContainer)
            )
        }

        @Test("Server list — empty")
        func serverListEmpty() throws {
            SnapshotEnvironment.pinUserDefaults()
            assertScreenSnapshot(
                NavigationStack {
                    ServerListView(
                        profilesVM: SnapshotFixtures.profilesViewModel(),
                        isShowingAddServer: .constant(false)
                    )
                }
                .modelContainer(SnapshotFixtures.emptyContainer),
                devices: [SnapshotEnvironment.primaryDevice]
            )
        }

        @Test("Server edit — new server form")
        func serverEditNew() throws {
            assertScreenSnapshot(
                NavigationStack { ServerEditView(profile: nil, isNew: true) }
                    .modelContainer(SnapshotFixtures.emptyContainer),
                devices: [SnapshotEnvironment.primaryDevice]
            )
        }

        @Test("Server preferences — loaded from mock")
        func serverPreferences() async throws {
            // Pre-load the view model from the deterministic mock and inject it,
            // so the snapshot captures the settled form rather than racing the
            // view's async onAppear load (which never completes under the
            // snapshot run-loop pump). See ServerPreferencesView's init.
            SnapshotEnvironment.pinUserDefaults(isDemoMode: true)
            defer { SnapshotEnvironment.pinUserDefaults() }
            let profile = try SnapshotFixtures.activeProfile()
            let viewModel = ServerPreferencesViewModel()
            viewModel.configure(
                with: profile,
                context: SnapshotFixtures.populatedContainer.mainContext,
                sessionFactory: SnapshotFixtures.sessionFactory
            )
            await viewModel.loadPreferences()
            assertScreenSnapshot(
                ServerPreferencesView(profile: profile, viewModel: viewModel)
                    .modelContainer(SnapshotFixtures.populatedContainer),
                devices: [SnapshotEnvironment.primaryDevice]
            )
        }
    }
}
