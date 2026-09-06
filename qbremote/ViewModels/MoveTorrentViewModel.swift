//
//  MoveTorrentViewModel.swift
//  qbremote
//

import Foundation

enum MoveTorrentState {
    case idle, submitting, success, failure(String)
}

@Observable
final class MoveTorrentViewModel {
    
    var savePath: String = ""
    var initialSavePath: String = ""
    var savePathSuggestions: [String] = []
    var submissionState: MoveTorrentState = .idle
    
    private weak var apiService: QBittorrentAPIServiceProtocol?
    private var torrentHash: String = ""
    
    func configure(apiService: QBittorrentAPIServiceProtocol, torrentHash: String, currentPath: String) {
        self.apiService = apiService
        self.torrentHash = torrentHash
        self.savePath = currentPath
        self.initialSavePath = currentPath
    }
    
    var canSubmit: Bool {
        !savePath.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    func loadSavePathSuggestions() async {
        guard let service = apiService else { return }
        
        var suggestions: Set<String> = []
        
        async let defaultPathTask = service.getDefaultSavePath()
        async let categoriesTask = service.getTorrentCategories()
        async let torrentsTask = service.getTorrents(filter: .all)
        
        let (defaultPath, categories, torrents) = await (
            (try? defaultPathTask) ?? "",
            (try? categoriesTask) ?? [:],
            (try? torrentsTask) ?? []
        )
        
        if !defaultPath.isEmpty {
            suggestions.insert(defaultPath)
        }
        
        for category in categories.values {
            if !category.savePath.isEmpty {
                suggestions.insert(category.savePath)
            }
        }
        
        for torrent in torrents {
            if !torrent.savePath.isEmpty {
                suggestions.insert(torrent.savePath)
            }
        }
        
        self.savePathSuggestions = Array(suggestions).sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
    }
    
    func submit() async {
        guard let service = apiService else {
            submissionState = .failure("No active server connection.")
            return
        }
        submissionState = .submitting
        do {
            try await service.setTorrentLocation(hashes: [torrentHash], location: savePath)
            submissionState = .success
        } catch let err as QBError {
            submissionState = .failure(err.errorDescription ?? "Unknown error")
        } catch {
            submissionState = .failure(error.localizedDescription)
        }
    }
}
