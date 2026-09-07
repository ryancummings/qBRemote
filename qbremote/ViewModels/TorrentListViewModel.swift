//
//  TorrentListViewModel.swift
//  qbremote
//

import Foundation
import Combine

// MARK: - ViewModel

@Observable
final class TorrentListViewModel {

    // MARK: - Published State

    var torrents: [Torrent] = []
    var stats: GlobalStats?
    var isLoading: Bool = false
    var error: String?
    var connectionStatus: ConnectionStatus {
        get { previewConnectionStatus ?? serverSession?.connectionStatus ?? .connecting }
        set { previewConnectionStatus = newValue }
    }
    // Static demo and snapshot fixtures can provide a status without running a session.
    private var previewConnectionStatus: ConnectionStatus?
    var lastUpdated: Date?
    var activeServerName: String = ""
    var activeServerURL: String = ""
    var activeProfileId: UUID?
    var activeUsername: String?

    // MARK: - Search & Filter

    var pendingHashes: Set<String> = []
    var searchQuery: String = ""
    var activeFilter: TorrentFilter = .all
    var activeCategoryFilter: String?
    var activeTagFilters: Set<String> = []
    var tagFilterMatchAll: Bool = true
    var activeLocationFilter: String?
    var activeTrackerFilter: String?
    
    var activeSortOption: TorrentSortOption = .addedOn
    var sortAscending: Bool = false

    var filteredTorrents: [Torrent] {
        let base: [Torrent]
        if activeFilter == .all {
            base = torrents
        } else if activeFilter == .active {
            base = torrents.filter { $0.uploadSpeed > 0 || $0.downloadSpeed > 0 }
        } else {
            base = torrents.filter { $0.state.filter == activeFilter }
        }

        var filtered = searchQuery.isEmpty 
            ? base 
            : base.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
            
        if let cat = activeCategoryFilter {
            if cat.isEmpty {
                // "None" category
                filtered = filtered.filter { $0.category.isEmpty }
            } else {
                filtered = filtered.filter { $0.category == cat }
            }
        }
        
        if !activeTagFilters.isEmpty {
            filtered = filtered.filter { torrent in
                let torrentTags = Set(torrent.tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
                if tagFilterMatchAll {
                    return activeTagFilters.isSubset(of: torrentTags)
                } else {
                    return !activeTagFilters.isDisjoint(with: torrentTags)
                }
            }
        }
        
        if let loc = activeLocationFilter {
            filtered = filtered.filter { $0.savePath == loc }
        }
        
        if let tracker = activeTrackerFilter {
            filtered = filtered.filter { $0.tracker == tracker }
        }

        return filtered.sorted { t1, t2 in
            let isAscending = sortAscending
            switch activeSortOption {
            case .addedOn:
                return isAscending ? t1.addedOn < t2.addedOn : t1.addedOn > t2.addedOn
            case .name:
                return isAscending ? t1.name.localizedStandardCompare(t2.name) == .orderedAscending : t1.name.localizedStandardCompare(t2.name) == .orderedDescending
            case .size:
                return isAscending ? t1.size < t2.size : t1.size > t2.size
            case .progress:
                return isAscending ? t1.progress < t2.progress : t1.progress > t2.progress
            case .upspeed:
                return isAscending ? t1.uploadSpeed < t2.uploadSpeed : t1.uploadSpeed > t2.uploadSpeed
            case .dlspeed:
                return isAscending ? t1.downloadSpeed < t2.downloadSpeed : t1.downloadSpeed > t2.downloadSpeed
            case .ratio:
                return isAscending ? t1.ratio < t2.ratio : t1.ratio > t2.ratio
            case .eta:
                // For ETA, >= 8_640_000 (100 days) is infinite
                let eta1 = (t1.eta < 0 || t1.eta >= 8_640_000) ? Int.max : t1.eta
                let eta2 = (t2.eta < 0 || t2.eta >= 8_640_000) ? Int.max : t2.eta
                return isAscending ? eta1 < eta2 : eta1 > eta2
            }
        }
    }

    // MARK: - Polling

    private var pollingTask: Task<Void, Never>?
    private var apiService: QBittorrentAPIServiceProtocol?
    private(set) var serverSession: QBServerSession?
    private var pollingInterval: Double = 5.0

    isolated deinit {
        pollingTask?.cancel()
    }

    // MARK: - Setup

    func configure(with profile: ServerProfile, injectedService: QBittorrentAPIServiceProtocol? = nil) {
        guard let url = profile.baseURL else { return }
        let service = injectedService ?? QBittorrentAPIService(baseURL: url, allowUntrustedSSL: profile.allowUntrustedSSL)

        stopPolling()
        self.serverSession = try? QBServerSession(profile: profile, service: service)

        self.apiService        = service
        self.pollingInterval   = profile.pollingInterval
        self.activeServerName  = profile.name.isEmpty ? profile.host : profile.name
        self.activeServerURL   = url.absoluteString
        self.activeProfileId   = profile.id
        self.activeUsername    = profile.username
        self.previewConnectionStatus = nil
        self.lastUpdated       = nil
        self.torrents          = []
        self.stats             = nil
        self.isLoading         = false
    }

    /// Authenticate and start polling. Call this when a server is first selected.
    func start(profile: ServerProfile) async {
        guard activeProfileId == profile.id, let session = serverSession else { return }
        isLoading = true
        do {
            _ = try await session.run(.globalStats)
            try await Task.sleep(for: .milliseconds(300))
            guard serverSession === session else { return }
            startPolling()
        } catch is CancellationError {
            if serverSession === session { isLoading = false }
        } catch {
            guard serverSession === session else { return }
            self.error = error.localizedDescription
            self.isLoading = false
        }
    }

    func startPolling() {
        stopPolling()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let interval = self?.pollingInterval else { return }
                await self?.fetchAll()
                do {
                    try await Task.sleep(for: .seconds(interval))
                } catch {
                    return
                }
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Fetch

    func fetchAll() async {

        guard let session = serverSession else { return }
        isLoading = torrents.isEmpty
        defer { if serverSession === session { isLoading = false } }
        do {
            async let fetchedTorrents = session.run(.torrents(filter: .all))
            async let fetchedStats = session.run(.globalStats)
            let result = try await (fetchedTorrents, fetchedStats)
            try Task.checkCancellation()
            guard serverSession === session else { return }
            (torrents, stats) = result
            error = nil
            lastUpdated = .now
        } catch is CancellationError {
            return
        } catch {
            guard serverSession === session else { return }
            self.error = error.localizedDescription
            if let qbError = error as? QBError {
                switch qbError {
                case .unauthorized, .forbidden, .loginFailed: stopPolling()
                default: break
                }
            }
        }
    }

    // MARK: - Torrent Actions

    func pause(torrent: Torrent) async {
        pendingHashes.insert(torrent.hash)
        defer { pendingHashes.remove(torrent.hash) }
        do {
            try await apiService?.pauseTorrents(hashes: [torrent.hash])
        } catch {
            self.error = error.localizedDescription
        }
        await fetchAll()
    }

    func resume(torrent: Torrent) async {
        pendingHashes.insert(torrent.hash)
        defer { pendingHashes.remove(torrent.hash) }
        do {
            try await apiService?.resumeTorrents(hashes: [torrent.hash])
        } catch {
            self.error = error.localizedDescription
        }
        await fetchAll()
    }

    func delete(torrent: Torrent, deleteFiles: Bool = false) async {
        pendingHashes.insert(torrent.hash)
        defer { pendingHashes.remove(torrent.hash) }
        do {
            try await apiService?.deleteTorrents(hashes: [torrent.hash], deleteFiles: deleteFiles)
        } catch {
            self.error = error.localizedDescription
        }
        await fetchAll()
    }

    func move(torrent: Torrent, to location: String) async {
        pendingHashes.insert(torrent.hash)
        defer { pendingHashes.remove(torrent.hash) }
        do {
            try await apiService?.setTorrentLocation(hashes: [torrent.hash], location: location)
        } catch {
            self.error = error.localizedDescription
        }
        await fetchAll()
    }

    // MARK: - Provide service reference for AddTorrentViewModel

    func apiServiceForAdding() -> QBittorrentAPIServiceProtocol? {
        apiService
    }
}
