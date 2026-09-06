//
//  SetTagsViewModel.swift
//  qbremote
//
//

import Foundation

enum SetTagsState {
    case idle, submitting, success, failure(String)
}

@Observable
final class SetTagsViewModel {
    
    var currentTags: Set<String> = []
    var initialTags: Set<String> = []
    var tagSuggestions: [String] = []
    var submissionState: SetTagsState = .idle
    var inputText: String = ""
    
    private weak var apiService: QBittorrentAPIServiceProtocol?
    private var torrentHash: String = ""
    
    func configure(apiService: QBittorrentAPIServiceProtocol, torrentHash: String, currentTagsString: String) {
        self.apiService = apiService
        self.torrentHash = torrentHash
        
        let parsed = currentTagsString
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        self.currentTags = Set(parsed)
        self.initialTags = Set(parsed)
    }
    
    func loadTagSuggestions() async {
        guard let service = apiService else { return }
        do {
            let tags = try await service.getTorrentTags()
            self.tagSuggestions = tags.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
        } catch {
            // Silently fail, just means no suggestions
            self.tagSuggestions = []
        }
    }
    
    func addTag(_ tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            currentTags.insert(trimmed)
        }
        inputText = ""
    }
    
    func removeTag(_ tag: String) {
        currentTags.remove(tag)
    }
    
    func submit() async {
        guard let service = apiService else {
            submissionState = .failure("No active server connection.")
            return
        }
        
        submissionState = .submitting
        
        let tagsToAdd = Array(currentTags.subtracting(initialTags))
        let tagsToRemove = Array(initialTags.subtracting(currentTags))
        
        do {
            if !tagsToAdd.isEmpty {
                try await service.addTorrentTags(hashes: [torrentHash], tags: tagsToAdd)
            }
            
            if !tagsToRemove.isEmpty {
                try await service.removeTorrentTags(hashes: [torrentHash], tags: tagsToRemove)
            }
            
            submissionState = .success
        } catch let err as QBError {
            submissionState = .failure(err.errorDescription ?? "Unknown error")
        } catch {
            submissionState = .failure(error.localizedDescription)
        }
    }
}
