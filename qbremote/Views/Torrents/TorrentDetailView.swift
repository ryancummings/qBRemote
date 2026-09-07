//
//  TorrentDetailView.swift
//  qbremote
//

import SwiftUI

struct TorrentDetailView: View {
    let torrent: Torrent
    let session: QBServerSession?
    let onPause: () -> Void
    let onResume: () -> Void
    let onDelete: (Bool) -> Void
    let onMove: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var showMoveSheet = false
    @State private var showCategorySheet = false
    @State private var showTagsSheet = false

    private var isPaused: Bool {
        [TorrentState.pausedDL, .pausedUP, .stoppedDL, .stoppedUP].contains(torrent.state)
    }

    var body: some View {
        List {
            // MARK: Progress
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(torrent.state.displayName, systemImage: torrent.state.icon)
                            .foregroundStyle(torrent.state.color)
                            .font(.headline)
                        Spacer()
                        Text("\(Int(torrent.progressPercent * 100))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: torrent.progressPercent)
                        .tint(torrent.state.color)
                }
                .padding(.vertical, 4)
            } header: { Text("Progress") }

            // MARK: Transfer
            Section("Transfer") {
                DetailRow(label: "Download Speed", value: torrent.downloadSpeed.speedString)
                DetailRow(label: "Upload Speed", value: torrent.uploadSpeed.speedString)
                DetailRow(label: "ETA", value: torrent.etaDisplay)
                DetailRow(label: "Total Size", value: torrent.size.sizeString)
                DetailRow(label: "Downloaded", value: torrent.completed.sizeString)
                DetailRow(label: "Uploaded", value: torrent.uploaded.sizeString)
                DetailRow(label: "Ratio", value: String(format: "%.3f", torrent.ratio))
            }

            // MARK: Peers
            Section("Peers") {
                DetailRow(label: "Seeds", value: "\(torrent.seedCount)")
                DetailRow(label: "Leechers", value: "\(torrent.leechCount)")
            }

            // MARK: Info
            Section("Info") {
                DetailRow(label: "Added On", value: torrent.addedOnDisplay)
                DetailRow(label: "Time Active", value: torrent.activeDurationDisplay)
                DetailRow(label: "Save Path", value: torrent.savePath.isEmpty ? "—" : torrent.savePath)
                DetailRow(label: "Tracker", value: torrent.tracker.isEmpty ? "—" : torrent.tracker)
                DetailRow(label: "Category", value: torrent.category.isEmpty ? "—" : torrent.category)
                DetailRow(label: "Tags", value: torrent.tags.isEmpty ? "—" : torrent.tags.replacingOccurrences(of: ",", with: ", "))
                DetailRow(label: "Hash", value: torrent.hash)
                    .font(.caption)
            }

        }
        .safeAreaInset(edge: .bottom) {
            bottomActionRow
        }
        .navigationTitle(torrent.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete \"\(torrent.name)\"?", isPresented: $showDeleteConfirm) {
            Button("Delete Torrent Only", role: .destructive) {
                onDelete(false)
                dismiss()
            }
            Button("Delete With Files", role: .destructive) {
                onDelete(true)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this torrent?")
        }
        .sheet(isPresented: $showMoveSheet) {
            MoveTorrentView(
                session: session,
                torrentHash: torrent.hash,
                currentPath: torrent.savePath,
                onSuccess: {
                    // When move succeeds, we close the sheet.
                    // The detail view dismisses itself so the user goes back to the list
                    // which will auto-refresh via the ViewModel.
                    dismiss()
                }
            )
        }
        .sheet(isPresented: $showCategorySheet) {
            SetCategoryView(
                session: session,
                torrentHash: torrent.hash,
                currentCategory: torrent.category,
                onSuccess: {
                    dismiss()
                }
            )
        }
        .sheet(isPresented: $showTagsSheet) {
            SetTagsView(
                session: session,
                torrentHash: torrent.hash,
                currentTags: torrent.tags,
                onSuccess: {
                    dismiss()
                }
            )
        }
    }

    // MARK: - Bottom Actions
    
    private var bottomActionRow: some View {
        HStack(spacing: 0) {
            if isPaused {
                actionButton(title: "Resume", icon: "play.fill", color: .green, identifier: "resume_torrent_button") {
                    onResume()
                    dismiss()
                }
            } else {
                actionButton(title: "Pause", icon: "pause.fill", color: .orange, identifier: "pause_torrent_button") {
                    onPause()
                    dismiss()
                }
            }
            
            Divider().frame(height: 32)
            
            actionButton(title: "Category", icon: "folder.badge.gearshape", color: .blue, identifier: "category_button") {
                showCategorySheet = true
            }
            
            Divider().frame(height: 32)
            
            actionButton(title: "Tags", icon: "tag", color: .cyan, identifier: "tags_button") {
                showTagsSheet = true
            }
            
            Divider().frame(height: 32)
            
            actionButton(title: "Move", icon: "folder", color: .indigo, identifier: "move_button") {
                showMoveSheet = true
            }
            
            Divider().frame(height: 32)
            
            actionButton(title: "Delete", icon: "trash", color: .red, identifier: "delete_torrent_button") {
                showDeleteConfirm = true
            }
        }
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    private func actionButton(title: String, icon: String, color: Color, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}


// MARK: - Helper Row

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }
}
