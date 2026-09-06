//
//  SetCategoryViewModel.swift
//  qbremote
//

import Foundation

enum SetCategoryState {
    case idle, submitting, success, failure(String)
}

@Observable
final class SetCategoryViewModel {
    
    var category: String = ""
    var initialCategory: String = ""
    var categorySuggestions: [String] = []
    var submissionState: SetCategoryState = .idle
    
    private weak var apiService: QBittorrentAPIServiceProtocol?
    private var torrentHash: String = ""
    
    func configure(apiService: QBittorrentAPIServiceProtocol, torrentHash: String, currentCategory: String) {
        self.apiService = apiService
        self.torrentHash = torrentHash
        self.category = currentCategory
        self.initialCategory = currentCategory
    }
    
    func loadCategorySuggestions() async {
        guard let service = apiService else { return }
        
        var suggestions: Set<String> = []
        
        async let categoriesTask = service.getTorrentCategories()
        async let torrentsTask = service.getTorrents(filter: .all)
        
        let (categories, torrents) = await (
            (try? categoriesTask) ?? [:],
            (try? torrentsTask) ?? []
        )
        
        for key in categories.keys {
            suggestions.insert(key)
        }
        
        for torrent in torrents {
            if !torrent.category.isEmpty {
                suggestions.insert(torrent.category)
            }
        }
        
        self.categorySuggestions = Array(suggestions).sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
    }
    
    func submit() async {
        guard let service = apiService else {
            submissionState = .failure("No active server connection.")
            return
        }
        submissionState = .submitting
        do {
            try await service.setTorrentCategory(hashes: [torrentHash], category: category)
            submissionState = .success
        } catch let err as QBError {
            submissionState = .failure(err.errorDescription ?? "Unknown error")
        } catch {
            submissionState = .failure(error.localizedDescription)
        }
    }
}
