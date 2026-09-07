//
//  SetTagsView.swift
//  qbremote
//
//

import SwiftUI

struct SetTagsView: View {
    let session: QBServerSession?
    let torrentHash: String
    let currentTags: String
    let onSuccess: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SetTagsViewModel()

    var body: some View {
        NavigationStack {
            List {
                // MARK: Current Tags
                Section {
                    if viewModel.currentTags.isEmpty {
                        Text("No tags set.")
                            .foregroundStyle(.secondary)
                    } else {
                        // Display current tags with delete button
                        ForEach(Array(viewModel.currentTags).sorted(), id: \.self) { tag in
                            HStack {
                                Text(tag)
                                Spacer()
                                Button {
                                    viewModel.removeTag(tag)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } header: {
                    Text("Current Tags")
                }
                
                // MARK: Add Tag Input
                Section {
                    HStack {
                        TextField("New Tag", text: $viewModel.inputText)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onSubmit {
                                viewModel.addTag(viewModel.inputText)
                            }
                        
                        Button {
                            viewModel.addTag(viewModel.inputText)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .accentColor)
                        }
                        .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonStyle(.plain)
                    }
                    
                    let filteredSuggestions = viewModel.tagSuggestions.filter { suggestion in
                        if viewModel.currentTags.contains(suggestion) { return false }
                        if viewModel.inputText.isEmpty { return true }
                        return suggestion.localizedCaseInsensitiveContains(viewModel.inputText)
                    }
                    
                    if !filteredSuggestions.isEmpty {
                        ForEach(filteredSuggestions, id: \.self) { suggestion in
                            Button {
                                viewModel.addTag(suggestion)
                            } label: {
                                HStack {
                                    Text(suggestion)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.secondary)
                                        .imageScale(.small)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Add Tag")
                } footer: {
                    Text("Select an existing tag or type a new one to assign it to the torrent.")
                }

                // MARK: Submit State Feedback
                switch viewModel.submissionState {
                case .success:
                    Section {
                        Label("Tags updated successfully!", systemImage: "checkmark.circle.fill")
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
            .navigationTitle("Manage Tags")
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
                    }
                }
            }
        }
        .onAppear {
            if let session {
                viewModel.configure(session: session, torrentHash: torrentHash, currentTagsString: currentTags)
                Task {
                    await viewModel.loadTagSuggestions()
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
