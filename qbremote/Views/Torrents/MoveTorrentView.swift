//
//  MoveTorrentView.swift
//  qbremote
//

import SwiftUI

struct MoveTorrentView: View {
    let session: QBServerSession?
    let torrentHash: String
    let currentPath: String
    let onSuccess: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = MoveTorrentViewModel()

    var body: some View {
        NavigationStack {
            List {
                // MARK: Save Path
                Section {
                    LabeledContent("Save Path") {
                        TextField("/downloads", text: $viewModel.savePath)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    
                    let sortedSuggestions: [String] = {
                        if viewModel.savePath.isEmpty || viewModel.savePath == viewModel.initialSavePath {
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
                    Text("The torrent data will be moved to this new location on the server.")
                }

                // MARK: Submit State Feedback
                switch viewModel.submissionState {
                case .success:
                    Section {
                        Label("Location updated successfully!", systemImage: "checkmark.circle.fill")
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
            .navigationTitle("Move Torrent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if case .submitting = viewModel.submissionState {
                        ProgressView()
                    } else {
                        Button("Apply") { submit() }
                            .disabled(!viewModel.canSubmit)
                    }
                }
            }
        }
        .onAppear {
            if let session {
                viewModel.configure(session: session, torrentHash: torrentHash, currentPath: currentPath)
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
}
