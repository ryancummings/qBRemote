import Foundation

/// Local criteria and results over the latest server snapshot.
@Observable
final class TorrentBrowsing {
    var torrents: [Torrent] = []
    private var serverID: UUID?

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
                let torrentTags = Self.tags(in: torrent)
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

    // MARK: - Available Options

    var availableCategories: [String] {
        Array(Set(torrents.map(\.category).filter { !$0.isEmpty })).sorted()
    }

    var availableTags: [String] {
        Array(Set(torrents.flatMap { Self.tags(in: $0) }.filter { !$0.isEmpty })).sorted()
    }

    var availableLocations: [String] {
        Array(Set(torrents.map(\.savePath).filter { !$0.isEmpty })).sorted()
    }

    var availableTrackers: [String] {
        Array(Set(torrents.map(\.tracker).filter { !$0.isEmpty })).sorted()
    }

    var hasActiveFilters: Bool {
        activeCategoryFilter != nil || !activeTagFilters.isEmpty ||
        activeLocationFilter != nil || activeTrackerFilter != nil
    }

    func selectServer(_ id: UUID) {
        guard serverID != id else { return }
        serverID = id
        clearFilters()
    }

    func clearFilters() {
        activeCategoryFilter = nil
        activeTagFilters.removeAll()
        activeLocationFilter = nil
        activeTrackerFilter = nil
    }

    private static func tags(in torrent: Torrent) -> Set<String> {
        Set(torrent.tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
    }

}
