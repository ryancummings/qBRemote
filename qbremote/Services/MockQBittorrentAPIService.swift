import Foundation

@MainActor
final class MockQBittorrentAPIService: QBSessionAdapter {
    
    var baseURL: URL = URL(string: "http://localhost:8080")!
    
    var shouldFailLogin = false
    var shouldFailRequests = false
    
    static var sharedMockTorrents: [Torrent] = Torrent.mockData()
    var mockGlobalStats = GlobalStats(downloadSpeed: 3_000_000, uploadSpeed: 2_000_000, downloadedData: 10_000_000_000, uploadedData: 5_000_000_000)
    var mockCategories: [String: QBittorrentAPIService.TorrentCategory] = [
        "Movies": QBittorrentAPIService.TorrentCategory(name: "Movies", savePath: "/downloads/movies"),
        "Linux ISOs": QBittorrentAPIService.TorrentCategory(name: "Linux ISOs", savePath: "/downloads/iso"),
        "OS": QBittorrentAPIService.TorrentCategory(name: "OS", savePath: "/downloads/os")
    ]
    var mockTags: [String] = ["linux", "ubuntu", "debian", "arch", "pi", "4k", "creative commons"]
    
    private var simulationTask: Task<Void, Never>?
    
    /// - Parameter simulate: When `true` (default), a 1-second tick randomly fluctuates
    ///   speeds/progress for demo realism. Snapshot tests pass `false` so rendered
    ///   output is pixel-deterministic.
    init(simulate: Bool = true) {
        if simulate {
            startSimulation()
        }
    }
    
    deinit {
        simulationTask?.cancel()
    }
    
    private func startSimulation() {
        simulationTask = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    simulateTick()
                } catch {
                    break
                }
            }
        }
    }
    
    private func simulateTick() {
        var totalDL = 0
        var totalUP = 0
        
        for i in 0..<Self.sharedMockTorrents.count {
            var torrent = Self.sharedMockTorrents[i]
            
            // Random fluctuation for realism
            let randomFluctuation = Double.random(in: 0.8...1.2)
            
            if torrent.state == .downloading {
                if torrent.downloadSpeed == 0 {
                    torrent.downloadSpeed = Int(Double.random(in: 500_000...2_000_000))
                }
                
                torrent.downloadSpeed = Int(Double(torrent.downloadSpeed) * randomFluctuation)
                
                // Add downloaded bytes
                let bytesDownloaded = torrent.downloadSpeed
                torrent.completed += bytesDownloaded
                torrent.downloaded += bytesDownloaded
                
                // Update progress
                if torrent.size > 0 {
                    torrent.progress = Double(torrent.completed) / Double(torrent.size)
                }
                
                // Calculate ETA
                if torrent.downloadSpeed > 0 {
                    let remainingBytes = torrent.size - torrent.completed
                    torrent.eta = max(0, remainingBytes / torrent.downloadSpeed)
                }
                
                // Transition to seeding if completed
                if torrent.progress >= 1.0 {
                    torrent.progress = 1.0
                    torrent.completed = torrent.size
                    torrent.state = .uploading
                    torrent.downloadSpeed = 0
                    torrent.uploadSpeed = Int(Double.random(in: 100_000...500_000))
                    torrent.eta = 8640000 // Infinite
                }
                
            } else if torrent.state == .uploading {
                if torrent.uploadSpeed == 0 {
                    torrent.uploadSpeed = Int(Double.random(in: 50_000...300_000))
                }
                
                torrent.uploadSpeed = Int(Double(torrent.uploadSpeed) * randomFluctuation)
                
                let bytesUploaded = torrent.uploadSpeed
                torrent.uploaded += bytesUploaded
                
                if torrent.size > 0 {
                    torrent.ratio = Double(torrent.uploaded) / Double(torrent.size)
                }
            }
            
            // Increment active duration if active
            if torrent.state == .downloading || torrent.state == .uploading {
                torrent.activeDuration += 1
            }
            
            totalDL += torrent.downloadSpeed
            totalUP += torrent.uploadSpeed
            
            Self.sharedMockTorrents[i] = torrent
        }
        
        mockGlobalStats = GlobalStats(
            downloadSpeed: totalDL,
            uploadSpeed: totalUP,
            downloadedData: mockGlobalStats.downloadedData + totalDL,
            uploadedData: mockGlobalStats.uploadedData + totalUP
        )
    }
    
    func setSessionCookie(_ cookie: String?) {}
    
    func login(username: String, password: String) async throws -> String {
        if shouldFailLogin {
            throw QBError.loginFailed("Invalid username or password.")
        }
        return "mock_sid_12345"
    }
    
    func logout() async throws {}
    
    func getTorrents(filter: TorrentFilter) async throws -> [Torrent] {
        if shouldFailRequests { throw QBError.requestFailed(500) }
        switch filter {
        case .all: return Self.sharedMockTorrents
        case .active: return Self.sharedMockTorrents.filter { $0.uploadSpeed > 0 || $0.downloadSpeed > 0 }
        default: return Self.sharedMockTorrents.filter { $0.state.filter == filter }
        }
    }
    
    func getGlobalStats() async throws -> GlobalStats {
        if shouldFailRequests { throw QBError.requestFailed(500) }
        return mockGlobalStats
    }
    
    func getDefaultSavePath() async throws -> String {
        return "/downloads/default"
    }
    
    func getTorrentCategories() async throws -> [String: QBittorrentAPIService.TorrentCategory] {
        if shouldFailRequests { throw QBError.requestFailed(500) }
        return mockCategories
    }
    
    var mockPreferences = ServerPreferences(
        listen_port: 6881, upnp: true, dl_limit: 0, up_limit: 0,
        alt_dl_limit: 10240, alt_up_limit: 10240, scheduler_enabled: false,
        schedule_from_hour: 8, schedule_from_min: 0,
        schedule_to_hour: 20, schedule_to_min: 0,
        schedule_days: 0,
        web_ui_port: 8080, use_https: false, dht: true, pex: true, lpd: true,
        encryption: 0, save_path: "/downloads", append_extension: true, preallocate_all: false
    )
    
    func getPreferences() async throws -> ServerPreferences {
        if shouldFailRequests { throw QBError.requestFailed(500) }
        return mockPreferences
    }
    
    func setPreferences(_ preferences: ServerPreferences) async throws {
        if shouldFailRequests { throw QBError.requestFailed(500) }
        // For the mock, just merge the updated values
        if let lp = preferences.listen_port { mockPreferences.listen_port = lp }
        if let upnp = preferences.upnp { mockPreferences.upnp = upnp }
        if let dl = preferences.dl_limit { mockPreferences.dl_limit = dl }
        if let up = preferences.up_limit { mockPreferences.up_limit = up }
        if let wp = preferences.web_ui_port { mockPreferences.web_ui_port = wp }
        if let uh = preferences.use_https { mockPreferences.use_https = uh }
    }
    
    func addTorrentByURL(_ magnetOrURL: String, savePath: String) async throws {
        if shouldFailRequests { throw QBError.requestFailed(500) }
        let newTorrent = Torrent(
            hash: UUID().uuidString.replacingOccurrences(of: "-", with: ""),
            name: URL(string: magnetOrURL)?.lastPathComponent ?? "New Torrent from URL",
            state: .downloading,
            progress: 0.0,
            downloadSpeed: 100_000,
            size: 10_000_000,
            savePath: savePath.isEmpty ? "/downloads" : savePath,
            category: "",
            eta: 3600
        )
        Self.sharedMockTorrents.append(newTorrent)
    }
    
    func addTorrentByData(_ data: Data, filename: String, savePath: String) async throws {
        if shouldFailRequests { throw QBError.requestFailed(500) }
        let newTorrent = Torrent(
            hash: UUID().uuidString.replacingOccurrences(of: "-", with: ""),
            name: filename.isEmpty ? "Uploaded Torrent" : filename,
            state: .downloading,
            progress: 0.0,
            downloadSpeed: 100_000,
            size: 10_000_000,
            savePath: savePath.isEmpty ? "/downloads" : savePath,
            category: "",
            eta: 3600
        )
        Self.sharedMockTorrents.append(newTorrent)
    }
    
    func pauseTorrents(hashes: [String]) async throws {
        if shouldFailRequests { throw QBError.requestFailed(500) }
        for i in 0..<Self.sharedMockTorrents.count {
            if hashes.contains(Self.sharedMockTorrents[i].hash) {
                if Self.sharedMockTorrents[i].progress >= 1.0 {
                    Self.sharedMockTorrents[i].state = .pausedUP
                } else {
                    Self.sharedMockTorrents[i].state = .pausedDL
                }
                Self.sharedMockTorrents[i].downloadSpeed = 0
                Self.sharedMockTorrents[i].uploadSpeed = 0
                Self.sharedMockTorrents[i].eta = 8640000
            }
        }
    }
    
    func resumeTorrents(hashes: [String]) async throws {
        if shouldFailRequests { throw QBError.requestFailed(500) }
        for i in 0..<Self.sharedMockTorrents.count {
            if hashes.contains(Self.sharedMockTorrents[i].hash) {
                if Self.sharedMockTorrents[i].progress >= 1.0 {
                    Self.sharedMockTorrents[i].state = .uploading
                    Self.sharedMockTorrents[i].uploadSpeed = Int(Double.random(in: 100_000...500_000))
                } else {
                    Self.sharedMockTorrents[i].state = .downloading
                    Self.sharedMockTorrents[i].downloadSpeed = Int(Double.random(in: 500_000...2_000_000))
                }
            }
        }
    }
    
    func deleteTorrents(hashes: [String], deleteFiles: Bool) async throws {
        if shouldFailRequests { throw QBError.requestFailed(500) }
        Self.sharedMockTorrents.removeAll { hashes.contains($0.hash) }
    }
    
    func setTorrentLocation(hashes: [String], location: String) async throws {
        if shouldFailRequests { throw QBError.requestFailed(500) }
        for i in 0..<Self.sharedMockTorrents.count {
            if hashes.contains(Self.sharedMockTorrents[i].hash) {
                Self.sharedMockTorrents[i].savePath = location
            }
        }
    }
    
    func setTorrentCategory(hashes: [String], category: String) async throws {
        if shouldFailRequests { throw QBError.requestFailed(500) }
        for i in 0..<Self.sharedMockTorrents.count {
            if hashes.contains(Self.sharedMockTorrents[i].hash) {
                Self.sharedMockTorrents[i].category = category
            }
        }
        
        if !category.isEmpty && mockCategories[category] == nil {
            mockCategories[category] = QBittorrentAPIService.TorrentCategory(name: category, savePath: "/downloads/\(category.lowercased())")
        }
    }
    
    func getTorrentTags() async throws -> [String] {
        if shouldFailRequests { throw QBError.requestFailed(500) }
        return mockTags
    }
    
    func addTorrentTags(hashes: [String], tags: [String]) async throws {
        if shouldFailRequests { throw QBError.requestFailed(500) }
        for i in 0..<Self.sharedMockTorrents.count {
            if hashes.contains(Self.sharedMockTorrents[i].hash) {
                var currentTags = Self.sharedMockTorrents[i].tags.split(separator: ",").map(String.init)
                for tag in tags {
                    if !currentTags.contains(tag) {
                        currentTags.append(tag)
                    }
                    if !mockTags.contains(tag) {
                        mockTags.append(tag)
                    }
                }
                Self.sharedMockTorrents[i].tags = currentTags.joined(separator: ",")
            }
        }
    }
    
    func removeTorrentTags(hashes: [String], tags: [String]) async throws {
        if shouldFailRequests { throw QBError.requestFailed(500) }
        for i in 0..<Self.sharedMockTorrents.count {
            if hashes.contains(Self.sharedMockTorrents[i].hash) {
                var currentTags = Self.sharedMockTorrents[i].tags.split(separator: ",").map(String.init)
                currentTags.removeAll { tags.contains($0) }
                Self.sharedMockTorrents[i].tags = currentTags.joined(separator: ",")
            }
        }
    }
}
