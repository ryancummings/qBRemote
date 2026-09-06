//
//  Torrent.swift
//  qbremote
//

import Foundation
import SwiftUI

// MARK: - Torrent State

nonisolated enum TorrentState: String, Decodable {
    case downloading
    case stalledDL           = "stalledDL"
    case uploading
    case stalledUP           = "stalledUP"
    case pausedDL            = "pausedDL"
    case pausedUP            = "pausedUP"
    case stoppedDL           = "stoppedDL"
    case stoppedUP           = "stoppedUP"
    case checkingDL          = "checkingDL"
    case checkingUP          = "checkingUP"
    case checkingResumeData  = "checkingResumeData"
    case moving
    case missingFiles        = "missingFiles"
    case error
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TorrentState(rawValue: raw) ?? .unknown
    }

    var displayName: String {
        switch self {
        case .downloading:                                       return "Downloading"
        case .stalledDL, .stalledUP:                             return "Stalled"
        case .uploading:                                         return "Seeding"
        case .pausedDL, .stoppedDL, .pausedUP, .stoppedUP:       return "Paused"
        case .checkingDL, .checkingUP, .checkingResumeData:      return "Checking"
        case .moving:                                            return "Moving"
        case .missingFiles:                                      return "Missing Files"
        case .error:                                             return "Error"
        case .unknown:                                           return "Unknown"
        }
    }

    var color: Color {
        switch self {
        case .downloading, .stalledDL:                           return .blue
        case .uploading, .stalledUP:                             return .green
        case .pausedDL, .pausedUP, .stoppedDL, .stoppedUP:     return .secondary
        case .checkingDL, .checkingUP, .checkingResumeData, .moving: return .orange
        case .missingFiles, .error:                              return .red
        case .unknown:                                           return .gray
        }
    }

    var icon: String {
        switch self {
        case .downloading, .stalledDL:                           return "arrow.down.circle.fill"
        case .uploading, .stalledUP:                             return "arrow.up.circle.fill"
        case .pausedDL, .pausedUP, .stoppedDL, .stoppedUP:     return "pause.circle.fill"
        case .checkingDL, .checkingUP, .checkingResumeData:     return "magnifyingglass.circle.fill"
        case .moving:                                            return "arrow.right.circle.fill"
        case .missingFiles, .error:                              return "exclamationmark.circle.fill"
        case .unknown:                                           return "questionmark.circle.fill"
        }
    }

    var filter: TorrentFilter {
        switch self {
        case .downloading, .stalledDL:                           return .downloading
        case .uploading, .stalledUP:                             return .seeding
        case .pausedDL, .pausedUP, .stoppedDL, .stoppedUP:     return .paused
        case .checkingDL, .checkingUP, .checkingResumeData, .moving: return .checking
        default:                                                 return .all
        }
    }
}

// MARK: - Filter

nonisolated enum TorrentFilter: String, CaseIterable, Identifiable {
    case all         = "All"
    case active      = "Active"
    case downloading = "Downloading"
    case seeding     = "Seeding"
    case paused      = "Paused"
    case checking    = "Checking"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all:         return "list.bullet"
        case .active:      return "bolt.circle"
        case .downloading: return "arrow.down.circle"
        case .seeding:     return "arrow.up.circle"
        case .paused:      return "pause.circle"
        case .checking:    return "magnifyingglass.circle"
        }
    }

    /// Maps to the qBittorrent API `filter` parameter
    var apiValue: String {
        switch self {
        case .all:         return "all"
        case .active:      return "active"
        case .downloading: return "downloading"
        case .seeding:     return "seeding"
        case .paused:      return "stopped"
        case .checking:    return "checking"
        }
    }
}

// MARK: - Sort Options

nonisolated enum TorrentSortOption: String, CaseIterable, Identifiable {
    case addedOn = "Added On"
    case name = "Name"
    case size = "Size"
    case progress = "Progress"
    case upspeed = "Upload Speed"
    case dlspeed = "Download Speed"
    case ratio = "Ratio"
    case eta = "ETA"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .addedOn: return "calendar"
        case .name: return "textformat.abc"
        case .size: return "externaldrive"
        case .progress: return "chart.pie"
        case .upspeed: return "arrow.up"
        case .dlspeed: return "arrow.down"
        case .ratio: return "arrow.left.arrow.right"
        case .eta: return "timer"
        }
    }
}

// MARK: - Torrent Model

nonisolated struct Torrent: Identifiable, Decodable {
    let hash: String
    var name: String
    var state: TorrentState
    var progress: Double        // 0.0–1.0
    var downloadSpeed: Int      // bytes/s
    var uploadSpeed: Int        // bytes/s
    let size: Int               // bytes (total)
    var completed: Int          // bytes downloaded
    var seedCount: Int
    var leechCount: Int
    var savePath: String
    var category: String
    var tags: String
    var tracker: String
    var eta: Int                // seconds (-1 = infinite)
    let addedOn: Int            // unix epoch
    var activeDuration: Int     // seconds
    var ratio: Double
    var downloaded: Int
    var uploaded: Int

    var id: String { hash }

    var progressPercent: Double { min(max(progress, 0), 1) }

    var etaDisplay: String {
        guard eta > 0, eta < 8_640_000 else { return "∞" }
        let h = eta / 3600
        let m = (eta % 3600) / 60
        let s = eta % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }

    var activeDurationDisplay: String {
        guard activeDuration > 0 else { return "0s" }
        let d = activeDuration / 86400
        let h = (activeDuration % 86400) / 3600
        let m = (activeDuration % 3600) / 60
        let s = activeDuration % 60
        
        var parts: [String] = []
        if d > 0 { parts.append("\(d)d") }
        if h > 0 { parts.append("\(h)h") }
        if m > 0 { parts.append("\(m)m") }
        if d == 0 && h == 0 && s > 0 { parts.append("\(s)s") }
        
        return parts.joined(separator: " ")
    }

    var addedOnDisplay: String {
        guard addedOn > 0 else { return "Unknown" }
        let date = Date(timeIntervalSince1970: TimeInterval(addedOn))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    enum CodingKeys: String, CodingKey {
        case hash, name, state, progress, size, completed
        case downloadSpeed = "dlspeed"
        case uploadSpeed   = "upspeed"
        case seedCount     = "num_seeds"
        case leechCount    = "num_leechs"
        case savePath      = "save_path"
        case category, tags, tracker, eta
        case addedOn       = "added_on"
        case activeDuration = "time_active"
        case ratio, downloaded, uploaded
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hash       = try  c.decode(String.self,       forKey: .hash)
        name       = try  c.decode(String.self,       forKey: .name)
        state      = try  c.decode(TorrentState.self, forKey: .state)
        progress       = try  c.decode(Double.self,       forKey: .progress)
        downloadSpeed  = try  c.decode(Int.self,          forKey: .downloadSpeed)
        uploadSpeed    = try  c.decode(Int.self,          forKey: .uploadSpeed)
        size           = try  c.decode(Int.self,          forKey: .size)
        completed      = (try? c.decode(Int.self,         forKey: .completed))  ?? 0
        seedCount      = (try? c.decode(Int.self,         forKey: .seedCount))   ?? 0
        leechCount     = (try? c.decode(Int.self,         forKey: .leechCount))  ?? 0
        savePath       = (try? c.decode(String.self,      forKey: .savePath))   ?? ""
        category       = (try? c.decode(String.self,      forKey: .category))   ?? ""
        tags           = (try? c.decode(String.self,      forKey: .tags))       ?? ""
        tracker        = (try? c.decode(String.self,      forKey: .tracker))    ?? ""
        eta            = (try? c.decode(Int.self,         forKey: .eta))        ?? -1
        addedOn        = (try? c.decode(Int.self,         forKey: .addedOn))    ?? 0
        activeDuration = (try? c.decode(Int.self,         forKey: .activeDuration)) ?? 0
        ratio          = (try? c.decode(Double.self,      forKey: .ratio))      ?? 0
        downloaded = (try? c.decode(Int.self,         forKey: .downloaded)) ?? 0
        uploaded   = (try? c.decode(Int.self,         forKey: .uploaded))   ?? 0
    }

    init(
        hash: String = UUID().uuidString,
        name: String,
        state: TorrentState,
        progress: Double,
        downloadSpeed: Int = 0,
        uploadSpeed: Int = 0,
        size: Int,
        completed: Int = 0,
        seedCount: Int = 0,
        leechCount: Int = 0,
        savePath: String = "/downloads",
        category: String = "",
        tags: String = "",
        tracker: String = "",
        eta: Int = -1,
        addedOn: Int = Int(Date().timeIntervalSince1970),
        activeDuration: Int = 0,
        ratio: Double = 0,
        downloaded: Int = 0,
        uploaded: Int = 0
    ) {
        self.hash = hash
        self.name = name
        self.state = state
        self.progress = progress
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
        self.size = size
        self.completed = completed
        self.seedCount = seedCount
        self.leechCount = leechCount
        self.savePath = savePath
        self.category = category
        self.tags = tags
        self.tracker = tracker
        self.eta = eta
        self.addedOn = addedOn
        self.activeDuration = activeDuration
        self.ratio = ratio
        self.downloaded = downloaded
        self.uploaded = uploaded
    }
}

extension Torrent {
    static func mockData() -> [Torrent] {
        return [
            Torrent(name: "Ubuntu 24.04 Desktop amd64.iso", state: .downloading, progress: 0.45, downloadSpeed: 2_500_000, size: 5_200_000_000, category: "OS", tags: "linux,ubuntu", tracker: "tracker.ubuntu.com", eta: 1100),
            Torrent(name: "Big Buck Bunny 1080p", state: .uploading, progress: 1.0, uploadSpeed: 800_000, size: 1_000_000_000, category: "Movies", tags: "4k,creative commons", tracker: "tracker.public.cc", ratio: 2.4),
            Torrent(name: "Debian 12.5.0 netinst", state: .downloading, progress: 0.12, downloadSpeed: 500_000, size: 650_000_000, category: "OS", tags: "linux,debian", tracker: "tracker.debian.org", eta: 1200),
            Torrent(name: "Arch Linux 2024.03.01", state: .pausedDL, progress: 0.88, size: 900_000_000, category: "OS", tags: "linux,arch", tracker: "tracker.archlinux.org"),
            Torrent(name: "Sintel 4k", state: .uploading, progress: 1.0, uploadSpeed: 1_200_000, size: 4_500_000_000, category: "Movies", tags: "4k", tracker: "tracker.public.cc", ratio: 1.1),
            Torrent(name: "Raspberry Pi OS Lite", state: .stalledDL, progress: 0.05, downloadSpeed: 0, size: 400_000_000, category: "OS", tags: "linux,pi", tracker: "tracker.raspberrypi.org", eta: -1)
        ]
    }
}

// MARK: - Global Transfer Stats

nonisolated struct GlobalStats: Decodable {
    let downloadSpeed: Int   // bytes/s
    let uploadSpeed: Int     // bytes/s
    let downloadedData: Int  // bytes total session
    let uploadedData: Int    // bytes total session

    enum CodingKeys: String, CodingKey {
        case downloadSpeed  = "dl_info_speed"
        case uploadSpeed    = "up_info_speed"
        case downloadedData = "dl_info_data"
        case uploadedData   = "up_info_data"
    }
}
