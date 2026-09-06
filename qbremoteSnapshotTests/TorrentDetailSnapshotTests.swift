//
//  TorrentDetailSnapshotTests.swift
//  qbremoteSnapshotTests
//
//  Note: the "Added On" row formats an absolute date via DateFormatter, which
//  uses the simulator's (= host machine's) time zone. References are recorded
//  in America/New_York; CI pins the runner to the same zone.
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
                    apiService: nil,
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
