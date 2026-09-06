import Testing
import Foundation
@testable import qbremote

@MainActor
struct TorrentListViewModelTests {

    @Test("ViewModel successfully fetches and populates mock data")
    func testFetchTorrents() async throws {
        let viewModel = TorrentListViewModel()
        let mockService = MockQBittorrentAPIService()
        let profile = ServerProfile(name: "Test Server", host: "127.0.0.1", port: 8080, username: "admin", isActive: true)
        
        viewModel.configure(with: profile, injectedService: mockService)
        
        // Use the start method which handles the initial fetch
        await viewModel.start(profile: profile)
        
        // Wait briefly for the async fetch to complete
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(viewModel.torrents.count > 0, "Torrents should be populated from mock service.")
        #expect(viewModel.stats != nil, "Global stats should be populated from mock service.")
        #expect(viewModel.connectionStatus == .connected, "Connection status should be connected.")
        #expect(viewModel.isLoading == false, "Loading state should be false after fetch completes.")
    }

    @Test("Filtering torrents by active status works correctly")
    func testFilterActiveTorrents() async throws {
        let viewModel = TorrentListViewModel()
        let mockService = MockQBittorrentAPIService()
        let profile = ServerProfile(name: "Test Server", host: "127.0.0.1", port: 8080, username: "admin", isActive: true)
        
        viewModel.configure(with: profile, injectedService: mockService)
        await viewModel.start(profile: profile)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Set filter to active
        viewModel.activeFilter = .active
        
        // Only Torrents with uploadSpeed or downloadSpeed > 0 should be shown
        let filtered = viewModel.filteredTorrents
        
        #expect(filtered.count > 0, "There should be active torrents in the mock data.")
        for torrent in filtered {
            #expect(torrent.uploadSpeed > 0 || torrent.downloadSpeed > 0, "Filtered torrent should be active.")
        }
    }
    
    @Test("Searching torrents filters by name")
    func testSearchTorrents() async throws {
        let viewModel = TorrentListViewModel()
        let mockService = MockQBittorrentAPIService()
        let profile = ServerProfile(name: "Test Server", host: "127.0.0.1", port: 8080, username: "admin", isActive: true)
        
        viewModel.configure(with: profile, injectedService: mockService)
        await viewModel.start(profile: profile)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        viewModel.searchQuery = "Ubuntu"
        let filtered = viewModel.filteredTorrents
        
        #expect(filtered.count == 1, "There should be one Ubuntu torrent.")
        #expect(filtered.first?.name.contains("Ubuntu") == true, "The filtered torrent should be Ubuntu.")
    }
}
