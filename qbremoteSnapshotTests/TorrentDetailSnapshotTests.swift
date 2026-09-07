//
//  TorrentDetailSnapshotTests.swift
//  qbremoteSnapshotTests
//
//  The "Added On" row uses the simulator's time zone. Run these tests in
//  America/New_York to match the reference images. See CONTRIBUTING.md.
//

import SnapshotTesting
import SwiftUI
import Testing

@testable import qbremote

extension SnapshotSuite {

    @MainActor
    @Suite
    struct TorrentDetailSnapshotTests {

        private func detailView(for torrent: Torrent) -> some View {
            NavigationStack {
                TorrentDetailView(
                    torrent: torrent,
                    session: nil,
                    onPause: {},
                    onResume: {},
                    onDelete: { _ in },
                    onMove: { _ in }
                )
            }
        }

        @Test("Torrent detail — downloading")
        func torrentDetailDownloading() {
            assertScreenSnapshot(detailView(for: SnapshotFixtures.downloadingTorrent))
        }

        @Test("Torrent detail — paused")
        func torrentDetailPaused() {
            assertScreenSnapshot(
                detailView(for: SnapshotFixtures.pausedTorrent),
                devices: [SnapshotEnvironment.primaryDevice]
            )
        }
    }
}
