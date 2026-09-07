//
//  SetCategoryView.swift
//  qbremote
//

import SwiftUI

struct SetCategoryView: View {
    let session: QBServerSession?
    let torrentHash: String
    let currentCategory: String
    let onSuccess: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SetCategoryViewModel()

    var body: some View {
        NavigationStack {
            List {
                // MARK: Category Input
                Section {
                    LabeledContent("Category") {
                        TextField("None", text: $viewModel.category)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    
                    let sortedSuggestions: [String] = {
                        if viewModel.category.isEmpty || viewModel.category == viewModel.initialCategory {
                            return viewModel.categorySuggestions
                        } else {
                            let text = viewModel.category
                            let relevant = viewModel.categorySuggestions.filter { $0.localizedCaseInsensitiveContains(text) }
                            let other = viewModel.categorySuggestions.filter { !$0.localizedCaseInsensitiveContains(text) }
                            return relevant + other
                        }
                    }()
                    
                    if !sortedSuggestions.isEmpty {
                        ForEach(sortedSuggestions, id: \.self) { suggestion in
                            Button {
                                viewModel.category = suggestion
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
                    Text("Select an existing category or type a new one to assign it to the torrent.")
                }

                // MARK: Submit State Feedback
                switch viewModel.submissionState {
                case .success:
                    Section {
                        Label("Category updated successfully!", systemImage: "checkmark.circle.fill")
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
            .navigationTitle("Set Category")
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
                viewModel.configure(session: session, torrentHash: torrentHash, currentCategory: currentCategory)
                Task {
                    await viewModel.loadCategorySuggestions()
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
