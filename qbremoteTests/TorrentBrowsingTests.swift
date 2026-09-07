import Foundation
import Testing
@testable import qbremote

@MainActor
struct TorrentBrowsingTests {
    @Test("Browsing combines search, status and server-specific criteria")
    func combinedCriteria() {
        let browsing = TorrentBrowsing()
        browsing.torrents = [
            Torrent(hash: "match", name: "Ubuntu Desktop", state: .downloading, progress: 0.5,
                    downloadSpeed: 10, size: 100, savePath: "/linux", category: "OS",
                    tags: "linux, desktop", tracker: "tracker"),
            Torrent(hash: "paused", name: "Ubuntu Desktop", state: .pausedDL, progress: 0.5,
                    size: 100, savePath: "/linux", category: "OS", tags: "linux, desktop", tracker: "tracker"),
            Torrent(hash: "different", name: "Ubuntu Server", state: .downloading, progress: 0.5,
                    downloadSpeed: 10, size: 100, savePath: "/linux", category: "OS", tags: "linux", tracker: "tracker")
        ]
        browsing.searchQuery = "UBUNTU"
        browsing.activeFilter = .active
        browsing.activeCategoryFilter = "OS"
        browsing.activeTagFilters = ["linux", "desktop"]
        browsing.activeLocationFilter = "/linux"
        browsing.activeTrackerFilter = "tracker"
        #expect(browsing.filteredTorrents.map(\.hash) == ["match"])
    }

    @Test("Available options follow live snapshots while disappeared criteria stay selected")
    func liveOptions() {
        let browsing = TorrentBrowsing()
        browsing.torrents = [
            Torrent(hash: "one", name: "One", state: .pausedDL, progress: 0, size: 1,
                    savePath: "/old", category: "old", tags: " linux, desktop, ,linux ", tracker: "old.tracker"),
            Torrent(hash: "two", name: "Two", state: .pausedDL, progress: 0, size: 1,
                    savePath: "", category: "", tags: "", tracker: "")
        ]
        #expect(browsing.availableCategories == ["old"])
        #expect(browsing.availableTags == ["desktop", "linux"])
        #expect(browsing.availableLocations == ["/old"])
        #expect(browsing.availableTrackers == ["old.tracker"])
        browsing.activeCategoryFilter = "old"
        browsing.activeTagFilters = ["linux"]
        browsing.activeLocationFilter = "/old"
        browsing.activeTrackerFilter = "old.tracker"
        browsing.torrents = [Torrent(hash: "new", name: "New", state: .pausedDL, progress: 0, size: 1,
                                     savePath: "/new", category: "new", tags: "fresh", tracker: "new.tracker")]
        #expect(browsing.availableCategories == ["new"])
        #expect(browsing.availableTags == ["fresh"])
        #expect(browsing.availableLocations == ["/new"])
        #expect(browsing.availableTrackers == ["new.tracker"])
        #expect(browsing.activeCategoryFilter == "old")
        #expect(browsing.activeTagFilters == ["linux"])
        #expect(browsing.activeLocationFilter == "/old")
        #expect(browsing.activeTrackerFilter == "old.tracker")
        #expect(browsing.filteredTorrents.isEmpty)
        #expect(browsing.hasActiveFilters)
        browsing.clearFilters()
        #expect(!browsing.hasActiveFilters)
        #expect(browsing.filteredTorrents.map(\.hash) == ["new"])
    }


    @Test("Server switches clear only server-specific criteria and reconnects retain them")
    func serverSwitch() {
        let browsing = TorrentBrowsing()
        let first = UUID()
        browsing.selectServer(first)
        browsing.searchQuery = "linux"
        browsing.activeFilter = .active
        browsing.activeSortOption = .name
        browsing.sortAscending = true
        browsing.tagFilterMatchAll = false
        browsing.activeCategoryFilter = "OS"
        browsing.activeTagFilters = ["linux"]
        browsing.activeLocationFilter = "/downloads"
        browsing.activeTrackerFilter = "tracker"
        browsing.selectServer(first)
        #expect(browsing.activeCategoryFilter == "OS")
        #expect(browsing.activeTagFilters == ["linux"])
        #expect(browsing.activeLocationFilter == "/downloads")
        #expect(browsing.activeTrackerFilter == "tracker")
        browsing.selectServer(UUID())
        #expect(!browsing.hasActiveFilters)
        #expect(browsing.searchQuery == "linux")
        #expect(browsing.activeFilter == .active)
        #expect(browsing.activeSortOption == .name)
        #expect(browsing.sortAscending)
        #expect(!browsing.tagFilterMatchAll)
    }


    @Test("All sort options preserve both ordering directions", arguments: TorrentSortOption.allCases)
    func sorting(option: TorrentSortOption) {
        let browsing = TorrentBrowsing()
        browsing.torrents = [
            Torrent(hash: "a", name: "File 10", state: .downloading, progress: 0.1, downloadSpeed: 20,
                    uploadSpeed: 30, size: 300, eta: 30, addedOn: 20, ratio: 2),
            Torrent(hash: "b", name: "File 2", state: .downloading, progress: 0.3, downloadSpeed: 30,
                    uploadSpeed: 20, size: 100, eta: 10, addedOn: 30, ratio: 1),
            Torrent(hash: "c", name: "File 1", state: .downloading, progress: 0.2, downloadSpeed: 10,
                    uploadSpeed: 10, size: 200, eta: 20, addedOn: 10, ratio: 3)
        ]
        let expected: [String]
        switch option {
        case .addedOn:  expected = ["c", "a", "b"]
        case .name:     expected = ["c", "b", "a"]
        case .size:     expected = ["b", "c", "a"]
        case .progress: expected = ["a", "c", "b"]
        case .upspeed:  expected = ["c", "b", "a"]
        case .dlspeed:  expected = ["c", "a", "b"]
        case .ratio:    expected = ["b", "a", "c"]
        case .eta:      expected = ["b", "c", "a"]
        }
        browsing.activeSortOption = option
        browsing.sortAscending = true
        #expect(browsing.filteredTorrents.map(\.hash) == expected)
        browsing.sortAscending = false
        #expect(browsing.filteredTorrents.map(\.hash) == Array(expected.reversed()))
    }

    @Test("Negative and threshold ETA values sort as infinity", arguments: [-1, 8_640_000, 9_000_000])
    func infiniteETA(eta: Int) {
        let browsing = TorrentBrowsing()
        browsing.torrents = [
            Torrent(hash: "infinite", name: "Infinite", state: .downloading, progress: 0, size: 1, eta: eta),
            Torrent(hash: "finite", name: "Finite", state: .downloading, progress: 0, size: 1, eta: 8_639_999),
            Torrent(hash: "zero", name: "Zero", state: .downloading, progress: 0, size: 1, eta: 0)
        ]
        browsing.activeSortOption = .eta
        browsing.sortAscending = true
        #expect(browsing.filteredTorrents.map(\.hash) == ["zero", "finite", "infinite"])
        browsing.sortAscending = false
        #expect(browsing.filteredTorrents.map(\.hash) == ["infinite", "finite", "zero"])
    }

    @Test("Status filters preserve stalled, stopped, checking and active behavior", arguments: TorrentFilter.allCases)
    func status(filter: TorrentFilter) {
        let browsing = TorrentBrowsing()
        browsing.torrents = [
            Torrent(hash: "download", name: "Download", state: .downloading, progress: 0, size: 1),
            Torrent(hash: "stalled", name: "Stalled", state: .stalledDL, progress: 0, uploadSpeed: 1, size: 1),
            Torrent(hash: "paused", name: "Paused", state: .stoppedUP, progress: 1, size: 1),
            Torrent(hash: "seed", name: "Seed", state: .uploading, progress: 1, uploadSpeed: 1, size: 1),
            Torrent(hash: "check", name: "Check", state: .checkingResumeData, progress: 0, size: 1),
            Torrent(hash: "move", name: "Move", state: .moving, progress: 1, size: 1),
            Torrent(hash: "error", name: "Error", state: .error, progress: 0, size: 1)
        ]
        let expected: Set<String>
        switch filter {
        case .all:         expected = ["download", "stalled", "paused", "seed", "check", "move", "error"]
        case .active:      expected = ["stalled", "seed"]
        case .downloading: expected = ["download", "stalled"]
        case .seeding:     expected = ["seed"]
        case .paused:      expected = ["paused"]
        case .checking:    expected = ["check", "move"]
        }
        browsing.activeFilter = filter
        #expect(Set(browsing.filteredTorrents.map(\.hash)) == expected)
    }

    @Test("Tags trim whitespace and preserve match-all and match-any including disappeared tags")
    func tags() {
        let browsing = TorrentBrowsing()
        browsing.torrents = [
            Torrent(hash: "both", name: "Both", state: .pausedDL, progress: 0, size: 1, tags: " linux, desktop\n"),
            Torrent(hash: "one", name: "One", state: .pausedDL, progress: 0, size: 1, tags: "linux"),
            Torrent(hash: "neither", name: "Neither", state: .pausedDL, progress: 0, size: 1)
        ]
        browsing.activeTagFilters = ["linux", "desktop"]
        #expect(browsing.filteredTorrents.map(\.hash) == ["both"])
        browsing.tagFilterMatchAll = false
        #expect(Set(browsing.filteredTorrents.map(\.hash)) == ["both", "one"])
        browsing.activeTagFilters = ["linux", "disappeared"]
        #expect(Set(browsing.filteredTorrents.map(\.hash)) == ["both", "one"])
        browsing.tagFilterMatchAll = true
        #expect(browsing.filteredTorrents.isEmpty)
    }

    @Test("Any and None category and tracker selections remain distinct")
    func noneFilters() {
        let browsing = TorrentBrowsing()
        browsing.torrents = [
            Torrent(hash: "none", name: "None", state: .pausedDL, progress: 0, size: 1),
            Torrent(hash: "category", name: "Category", state: .pausedDL, progress: 0, size: 1, category: "OS"),
            Torrent(hash: "tracker", name: "Tracker", state: .pausedDL, progress: 0, size: 1, tracker: "tracker")
        ]
        #expect(!browsing.hasActiveFilters)
        browsing.activeCategoryFilter = ""
        #expect(browsing.hasActiveFilters)
        #expect(Set(browsing.filteredTorrents.map(\.hash)) == ["none", "tracker"])
        browsing.activeTrackerFilter = ""
        #expect(browsing.filteredTorrents.map(\.hash) == ["none"])
        browsing.activeCategoryFilter = nil
        #expect(Set(browsing.filteredTorrents.map(\.hash)) == ["none", "category"])
    }

    @Test("Each disappeared server-specific criterion keeps results empty", arguments: ["category", "tag", "location", "tracker"])
    func disappearedCriterion(kind: String) {
        let browsing = TorrentBrowsing()
        browsing.torrents = [Torrent(name: "Old", state: .pausedDL, progress: 0, size: 1,
                                     savePath: "old", category: "old", tags: "old", tracker: "old")]
        switch kind {
        case "category": browsing.activeCategoryFilter = "old"
        case "tag":      browsing.activeTagFilters = ["old"]
        case "location": browsing.activeLocationFilter = "old"
        default:         browsing.activeTrackerFilter = "old"
        }
        #expect(browsing.filteredTorrents.count == 1)
        browsing.torrents = [Torrent(name: "New", state: .pausedDL, progress: 0, size: 1)]
        #expect(browsing.filteredTorrents.isEmpty)
        #expect(browsing.hasActiveFilters)
        browsing.clearFilters()
        #expect(browsing.filteredTorrents.count == 1)
    }

    @Test("Explicit clear preserves search, status, sort and tag-match mode")
    func clear() {
        let browsing = TorrentBrowsing()
        browsing.searchQuery = "name"
        browsing.activeFilter = .paused
        browsing.activeSortOption = .size
        browsing.sortAscending = true
        browsing.tagFilterMatchAll = false
        #expect(!browsing.hasActiveFilters)
        browsing.activeCategoryFilter = "category"
        browsing.activeTagFilters = ["tag"]
        browsing.activeLocationFilter = "location"
        browsing.activeTrackerFilter = "tracker"
        browsing.clearFilters()
        #expect(!browsing.hasActiveFilters)
        #expect(browsing.searchQuery == "name")
        #expect(browsing.activeFilter == .paused)
        #expect(browsing.activeSortOption == .size)
        #expect(browsing.sortAscending)
        #expect(!browsing.tagFilterMatchAll)
    }

    @Test("Configuring the active server feeds browsing reset only when its identity changes")
    func viewModelServerSwitch() {
        let viewModel = TorrentListViewModel()
        let first = ServerProfile(host: "first.local")
        let second = ServerProfile(host: "second.local")
        let factory = QBServerSessionFactory(makeService: { _, _ in MockQBittorrentAPIService(simulate: false) })
        viewModel.configure(with: first, sessionFactory: factory)
        let browsing = viewModel.browsing
        browsing.searchQuery = "Ubuntu"
        browsing.activeSortOption = .name
        browsing.activeCategoryFilter = "OS"
        viewModel.configure(with: first, sessionFactory: factory)
        #expect(browsing.activeCategoryFilter == "OS")
        viewModel.configure(with: second, sessionFactory: factory)
        #expect(viewModel.browsing === browsing)
        #expect(!browsing.hasActiveFilters)
        #expect(browsing.searchQuery == "Ubuntu")
        #expect(browsing.activeSortOption == .name)
        viewModel.torrents = [Torrent(name: "Ubuntu", state: .pausedDL, progress: 0, size: 1)]
        #expect(browsing.filteredTorrents.count == 1)
    }

}
