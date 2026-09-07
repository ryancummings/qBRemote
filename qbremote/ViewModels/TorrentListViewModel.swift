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

    let browsing = TorrentBrowsing()
    var torrents: [Torrent] {
        get { browsing.torrents }
        set { browsing.torrents = newValue }
    }
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

    // MARK: - Pending Actions

    var pendingHashes: Set<String> = []
    // MARK: - Polling

    private var pollingTask: Task<Void, Never>?
    private(set) var serverSession: QBServerSession?
    private var pollingInterval: Double = 5.0

    isolated deinit {
        pollingTask?.cancel()
    }

    // MARK: - Setup

    func configure(with profile: ServerProfile, sessionFactory: QBServerSessionFactory = QBServerSessionFactory()) {
        guard let url = profile.baseURL else { return }

        stopPolling()
        self.serverSession = try? sessionFactory.session(for: profile)
        browsing.selectServer(profile.id)

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
            try await serverSession?.run(.pauseTorrents(hashes: [torrent.hash]))
        } catch {
            self.error = error.localizedDescription
        }
        await fetchAll()
    }

    func resume(torrent: Torrent) async {
        pendingHashes.insert(torrent.hash)
        defer { pendingHashes.remove(torrent.hash) }
        do {
            try await serverSession?.run(.resumeTorrents(hashes: [torrent.hash]))
        } catch {
            self.error = error.localizedDescription
        }
        await fetchAll()
    }

    func delete(torrent: Torrent, deleteFiles: Bool = false) async {
        pendingHashes.insert(torrent.hash)
        defer { pendingHashes.remove(torrent.hash) }
        do {
            try await serverSession?.run(.deleteTorrents(hashes: [torrent.hash], deleteFiles: deleteFiles))
        } catch {
            self.error = error.localizedDescription
        }
        await fetchAll()
    }

    func move(torrent: Torrent, to location: String) async {
        pendingHashes.insert(torrent.hash)
        defer { pendingHashes.remove(torrent.hash) }
        do {
            try await serverSession?.run(.setTorrentLocation(hashes: [torrent.hash], location: location))
        } catch {
            self.error = error.localizedDescription
        }
        await fetchAll()
    }

}
