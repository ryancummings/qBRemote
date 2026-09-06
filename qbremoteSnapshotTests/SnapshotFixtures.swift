//
//  SnapshotFixtures.swift
//  qbremoteSnapshotTests
//
//  Frozen, pixel-deterministic data for snapshot tests.
//
//  Unlike `Torrent.mockData()` / `MockQBittorrentAPIService` (whose hashes and
//  `addedOn` default to "now"/random UUIDs, and whose simulation tick randomly
//  fluctuates speeds), every value here is an explicit constant so rendered
//  output never drifts between runs or machines.
//

import Foundation
import SwiftData

@testable import qbremote

enum SnapshotFixtures {

    /// 2025-01-01 12:00:00 UTC — fixed epoch for all `addedOn` values.
    static let referenceEpoch = 1_735_732_800

    // MARK: - Torrents

    /// Mirrors the demo dataset, but with constant hashes, distinct fixed
    /// `addedOn` values (stable sort order), and fixed counters.
    static func torrents() -> [Torrent] {
        [
            Torrent(
                hash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1",
                name: "Ubuntu 24.04 Desktop amd64.iso",
                state: .downloading,
                progress: 0.45,
                downloadSpeed: 2_500_000,
                size: 5_200_000_000,
                completed: 2_340_000_000,
                seedCount: 42,
                leechCount: 7,
                category: "OS",
                tags: "linux,ubuntu",
                tracker: "tracker.ubuntu.com",
                eta: 1100,
                addedOn: referenceEpoch - 3_600,
                activeDuration: 5_400,
                downloaded: 2_340_000_000
            ),
            Torrent(
                hash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa2",
                name: "Big Buck Bunny 1080p",
                state: .uploading,
                progress: 1.0,
                uploadSpeed: 800_000,
                size: 1_000_000_000,
                completed: 1_000_000_000,
                seedCount: 12,
                leechCount: 3,
                category: "Movies",
                tags: "4k,creative commons",
                tracker: "tracker.public.cc",
                addedOn: referenceEpoch - 86_400,
                activeDuration: 90_000,
                ratio: 2.4,
                downloaded: 1_000_000_000,
                uploaded: 2_400_000_000
            ),
            Torrent(
                hash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa3",
                name: "Debian 12.5.0 netinst",
                state: .downloading,
                progress: 0.12,
                downloadSpeed: 500_000,
                size: 650_000_000,
                completed: 78_000_000,
                seedCount: 18,
                leechCount: 4,
                category: "OS",
                tags: "linux,debian",
                tracker: "tracker.debian.org",
                eta: 1200,
                addedOn: referenceEpoch - 7_200,
                activeDuration: 900,
                downloaded: 78_000_000
            ),
            Torrent(
                hash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa4",
                name: "Arch Linux 2024.03.01",
                state: .pausedDL,
                progress: 0.88,
                size: 900_000_000,
                completed: 792_000_000,
                seedCount: 30,
                leechCount: 2,
                category: "OS",
                tags: "linux,arch",
                tracker: "tracker.archlinux.org",
                addedOn: referenceEpoch - 172_800,
                activeDuration: 43_200,
                downloaded: 792_000_000
            ),
            Torrent(
                hash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa5",
                name: "Sintel 4k",
                state: .uploading,
                progress: 1.0,
                uploadSpeed: 1_200_000,
                size: 4_500_000_000,
                completed: 4_500_000_000,
                seedCount: 25,
                leechCount: 9,
                category: "Movies",
                tags: "4k",
                tracker: "tracker.public.cc",
                addedOn: referenceEpoch - 259_200,
                activeDuration: 200_000,
                ratio: 1.1,
                downloaded: 4_500_000_000,
                uploaded: 4_950_000_000
            ),
            Torrent(
                hash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6",
                name: "Raspberry Pi OS Lite",
                state: .stalledDL,
                progress: 0.05,
                downloadSpeed: 0,
                size: 400_000_000,
                completed: 20_000_000,
                seedCount: 0,
                leechCount: 1,
                category: "OS",
                tags: "linux,pi",
                tracker: "tracker.raspberrypi.org",
                eta: -1,
                addedOn: referenceEpoch - 345_600,
                activeDuration: 60,
                downloaded: 20_000_000
            ),
        ]
    }

    static func stats() -> GlobalStats {
        GlobalStats(
            downloadSpeed: 3_000_000,
            uploadSpeed: 2_000_000,
            downloadedData: 10_000_000_000,
            uploadedData: 5_000_000_000
        )
    }

    // MARK: - View Models

    /// A list view model seeded to a connected, fully-loaded state — no
    /// service attached, so nothing polls or mutates during the snapshot.
    @MainActor
    static func listViewModel(torrents: [Torrent]? = nil) -> TorrentListViewModel {
        let viewModel = TorrentListViewModel()
        viewModel.torrents = torrents ?? Self.torrents()
        viewModel.stats = stats()
        viewModel.connectionStatus = .connected
        viewModel.activeServerName = "Home Server"
        viewModel.activeServerURL = "http://192.168.1.100:8080"
        viewModel.isLoading = false
        return viewModel
    }

    /// Detail-screen subjects.
    static var downloadingTorrent: Torrent { torrents()[0] }
    static var pausedTorrent: Torrent { torrents()[3] }

    @MainActor
    static func profilesViewModel() -> ServerProfilesViewModel {
        let viewModel = ServerProfilesViewModel()
        // `.connected` short-circuits ServerListView's onAppear connection
        // check (it only fires while `.idle`), keeping snapshots network-free.
        viewModel.activeConnectionStatus = .connected
        return viewModel
    }

    // MARK: - Server Profiles

    /// Frozen profiles: fixed UUIDs and staggered `createdAt` (the list sorts
    /// by it). Distinct shapes: named+active, HTTPS, and port-less host.
    static func serverProfiles() -> [ServerProfile] {
        let base = Date(timeIntervalSince1970: TimeInterval(referenceEpoch))
        return [
            ServerProfile(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
                name: "Home Server",
                host: "192.168.1.100",
                port: 8080,
                isActive: true,
                createdAt: base.addingTimeInterval(-259_200),
                lastUpdated: base
            ),
            ServerProfile(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
                name: "Seedbox",
                host: "seedbox.example.com",
                port: 443,
                useHTTPS: true,
                createdAt: base.addingTimeInterval(-172_800),
                lastUpdated: base
            ),
            ServerProfile(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003") ?? UUID(),
                name: "",
                host: "nas.local",
                port: nil,
                createdAt: base.addingTimeInterval(-86_400),
                lastUpdated: base
            ),
        ]
    }

    // MARK: - SwiftData

    /// Process-lifetime in-memory containers. They deliberately never
    /// deallocate: async `onAppear` tasks in the hosted views can retain
    /// model instances past the end of a test, and a container torn down
    /// underneath them destroys its models (SwiftData fatal error).
    @MainActor
    static let emptyContainer: ModelContainer = makeContainer(profiles: [])

    @MainActor
    static let populatedContainer: ModelContainer = makeContainer(profiles: serverProfiles())

    /// The active fixture profile, owned by `populatedContainer`.
    @MainActor
    static func activeProfile() throws -> ServerProfile {
        var descriptor = FetchDescriptor<ServerProfile>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        guard let profile = try populatedContainer.mainContext.fetch(descriptor).first else {
            throw FixtureError.missingProfile
        }
        return profile
    }

    enum FixtureError: Error {
        case missingProfile
    }

    @MainActor
    private static func makeContainer(profiles: [ServerProfile]) -> ModelContainer {
        do {
            let container = try ModelContainer(
                for: ServerProfile.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            for profile in profiles {
                container.mainContext.insert(profile)
            }
            try container.mainContext.save()
            return container
        } catch {
            fatalError("Failed to build in-memory fixture container: \(error)")
        }
    }
}
