//
//  AddTorrentViewModel.swift
//  qbremote
//

import Foundation

enum AddTorrentMode: String, CaseIterable, Identifiable {
    case url  = "URL / Magnet"
    case file = ".torrent File"
    var id: String { rawValue }
}

enum AddTorrentState {
    case idle, submitting, success, failure(String)
}

@Observable
final class AddTorrentViewModel {

    var mode: AddTorrentMode = .url
    var magnetURL: String = ""
    var savePath: String = ""
    var selectedFileData: Data?
    var selectedFilename: String?
    var submissionState: AddTorrentState = .idle
    var savePathSuggestions: [String] = []

    private weak var apiService: QBittorrentAPIServiceProtocol?

    func configure(apiService: QBittorrentAPIServiceProtocol, initialURL: URL? = nil) {
        self.apiService = apiService
        if let url = initialURL {
            if url.isFileURL {
                let accessed = url.startAccessingSecurityScopedResource()
                defer {
                    if accessed {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                mode = .file
                selectedFilename = url.lastPathComponent
                selectedFileData = try? Data(contentsOf: url)
            } else if url.scheme == "magnet" {
                mode = .url
                magnetURL = url.absoluteString
            }
        }
    }

    var canSubmit: Bool {
        switch mode {
        case .url:  return !magnetURL.trimmingCharacters(in: .whitespaces).isEmpty
        case .file: return selectedFileData != nil
        }
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
            switch mode {
            case .url:
                try await service.addTorrentByURL(magnetURL.trimmingCharacters(in: .whitespaces), savePath: savePath)
            case .file:
                guard let data = selectedFileData, let name = selectedFilename else {
                    submissionState = .failure("No file selected.")
                    return
                }
                try await service.addTorrentByData(data, filename: name, savePath: savePath)
            }
            submissionState = .success
        } catch let err as QBError {
            submissionState = .failure(err.errorDescription ?? "Unknown error")
        } catch {
            submissionState = .failure(error.localizedDescription)
        }
    }

    func reset() {
        magnetURL = ""
        savePath = ""
        selectedFileData = nil
        selectedFilename = nil
        submissionState = .idle
    }
}
