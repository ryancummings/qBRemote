//
//  AddTorrentSnapshotTests.swift
//  qbremoteSnapshotTests
//

import SnapshotTesting
import SwiftUI
import Testing

@testable import qbremote

extension SnapshotSuite {

    @MainActor
    @Suite
    struct AddTorrentSnapshotTests {

        @Test("Add torrent — URL mode")
        func addTorrentURLMode() {
            // AddTorrentView provides its own NavigationStack.
            assertScreenSnapshot(
                AddTorrentView(apiService: nil, onSuccess: {}),
                devices: [SnapshotEnvironment.primaryDevice]
            )
        }
    }
}
