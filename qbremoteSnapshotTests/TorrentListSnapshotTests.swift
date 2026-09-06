//
//  TorrentListSnapshotTests.swift
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
    struct TorrentListSnapshotTests {

        @Test("Torrent list — populated")
        func torrentListPopulated() throws {
            let viewModel = SnapshotFixtures.listViewModel()
            assertScreenSnapshot(
                NavigationStack { TorrentListView(torrentVM: viewModel) }
                    .modelContainer(SnapshotFixtures.emptyContainer)
            )
        }

        @Test("Torrent list — empty")
        func torrentListEmpty() throws {
            let viewModel = SnapshotFixtures.listViewModel(torrents: [])
            assertScreenSnapshot(
                NavigationStack { TorrentListView(torrentVM: viewModel) }
                    .modelContainer(SnapshotFixtures.emptyContainer),
                devices: [SnapshotEnvironment.primaryDevice]
            )
        }

        @Test("Torrent list — connection error")
        func torrentListConnectionError() throws {
            let viewModel = SnapshotFixtures.listViewModel(torrents: [])
            viewModel.stats = nil // disconnected: no live transfer stats
            let message = "Could not connect to the server. Please check the address and your network."
            viewModel.error = message
            viewModel.connectionStatus = .error(message)
            assertScreenSnapshot(
                NavigationStack { TorrentListView(torrentVM: viewModel) }
                    .modelContainer(SnapshotFixtures.emptyContainer),
                devices: [SnapshotEnvironment.primaryDevice]
            )
        }
    }
}
