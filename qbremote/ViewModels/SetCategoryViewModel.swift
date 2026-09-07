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
    
    private var session: QBServerSession?
    private var torrentHash: String = ""
    
    func configure(session: QBServerSession, torrentHash: String, currentCategory: String) {
        self.session = session
        self.torrentHash = torrentHash
        self.category = currentCategory
        self.initialCategory = currentCategory
    }
    
    func loadCategorySuggestions() async {
        guard let session else { return }
        
        var suggestions: Set<String> = []
        
        async let categoriesTask = session.run(.torrentCategories)
        async let torrentsTask = session.run(.torrents(filter: .all))
        
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
        guard let session else {
            submissionState = .failure("No active server connection.")
            return
        }
        submissionState = .submitting
        do {
            try await session.run(.setTorrentCategory(hashes: [torrentHash], category: category))
            submissionState = .success
        } catch let err as QBError {
            submissionState = .failure(err.errorDescription ?? "Unknown error")
        } catch {
            submissionState = .failure(error.localizedDescription)
        }
    }
}
