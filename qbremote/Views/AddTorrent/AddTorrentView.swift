//
//  AddTorrentView.swift
//  qbremote
//

import SwiftUI
import UniformTypeIdentifiers

struct AddTorrentView: View {
    let apiService: QBittorrentAPIServiceProtocol?
    let initialURL: URL?
    let onSuccess: () -> Void

    init(apiService: QBittorrentAPIServiceProtocol?, initialURL: URL? = nil, onSuccess: @escaping () -> Void) {
        self.apiService = apiService
        self.initialURL = initialURL
        self.onSuccess = onSuccess
    }

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AddTorrentViewModel()
    @State private var showFilePicker = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: Mode Picker
                Section {
                    Picker("Add via", selection: $viewModel.mode) {
                        ForEach(AddTorrentMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))

                // MARK: URL / Magnet
                if viewModel.mode == .url {
                    Section("Magnet Link or URL") {
                        TextField("magnet:?xt=urn:btih:…", text: $viewModel.magnetURL, axis: .vertical)
                            .accessibilityIdentifier("magnet_url_field")
                            .lineLimit(3...6)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                }

                // MARK: File Picker
                if viewModel.mode == .file {
                    Section(".torrent File") {
                        Button {
                            showFilePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "doc.badge.plus")
                                if let name = viewModel.selectedFilename {
                                    Text(name)
                                        .lineLimit(1)
                                } else {
                                    Text("Choose .torrent File…")
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if viewModel.selectedFileData != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .fileImporter(
                            isPresented: $showFilePicker,
                            allowedContentTypes: [UTType(filenameExtension: "torrent") ?? .data]
                        ) { result in
                            handleFilePick(result)
                        }
                    }
                }

                // MARK: Save Path
                Section {
                    TextField("Save Path (e.g., /downloads)", text: $viewModel.savePath)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                    
                    let sortedSuggestions: [String] = {
                        if viewModel.savePath.isEmpty {
                            return viewModel.savePathSuggestions
                        } else {
                            let text = viewModel.savePath
                            let relevant = viewModel.savePathSuggestions.filter { $0.localizedCaseInsensitiveContains(text) }
                            let other = viewModel.savePathSuggestions.filter { !$0.localizedCaseInsensitiveContains(text) }
                            return relevant + other
                        }
                    }()
                    
                    if !sortedSuggestions.isEmpty {
                        ForEach(sortedSuggestions, id: \.self) { suggestion in
                            Button {
                                viewModel.savePath = suggestion
                            } label: {
                                HStack {
                                    Text(suggestion)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "arrow.up.left")
                                        .foregroundColor(.secondary)
                                        .imageScale(.small)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("Leave blank to use the server's default download location.")
                }

                // MARK: Submit State Feedback
                switch viewModel.submissionState {
                case .success:
                    Section {
                        Label("Torrent added successfully!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                case .failure(let msg):
                    Section {
                        Label(msg, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                default:
                    EmptyView()
                }
            }
            .navigationTitle("Add Torrent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if case .submitting = viewModel.submissionState {
                        ProgressView()
                    } else {
                        Button("Add") { submit() }
                            .accessibilityIdentifier("add_torrent_submit_button")
                            .disabled(!viewModel.canSubmit)
                    }
                }
            }
        }
        .onAppear {
            if let service = apiService {
                viewModel.configure(apiService: service, initialURL: initialURL)
                Task {
                    await viewModel.loadSavePathSuggestions()
                }
            }
        }
        .presentationSizing(.form)
    }

    // MARK: - Helpers

    private func submit() {
        Task {
            await viewModel.submit()
            if case .success = viewModel.submissionState {
                onSuccess()
                try? await Task.sleep(for: .seconds(0.6))
                dismiss()
            }
        }
    }

    private func handleFilePick(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            viewModel.selectedFilename = url.lastPathComponent
            viewModel.selectedFileData = try? Data(contentsOf: url)
        case .failure(let error):
            print("[AddTorrent] File pick error: \(error)")
        }
    }
}
