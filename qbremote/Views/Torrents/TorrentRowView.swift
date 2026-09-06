//
//  TorrentRowView.swift
//  qbremote
//

import SwiftUI

struct TorrentRowView: View {
    let torrent: Torrent
    let isPending: Bool

    private var isPaused: Bool {
        [TorrentState.pausedDL, .pausedUP, .stoppedDL, .stoppedUP].contains(torrent.state)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Name + State badge / spinner
            HStack(alignment: .top) {
                Text(torrent.name)
                    .accessibilityIdentifier("torrent_name_\(torrent.name)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                Spacer()
                if isPending {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    StateBadge(state: torrent.state)
                }
            }

            // Progress bar
            ProgressView(value: torrent.progressPercent)
                .tint(torrent.state.color)

            // Speed / size row
            HStack {
                if torrent.downloadSpeed > 0 {
                    Label("DL: \(torrent.downloadSpeed.speedString)", systemImage: "arrow.down")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                if torrent.uploadSpeed > 0 {
                    Label("UP: \(torrent.uploadSpeed.speedString)", systemImage: "arrow.up")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                Spacer()
                Text("\(Int(torrent.progressPercent * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                if !isPaused, torrent.downloadSpeed > 0 {
                    Text("· \(torrent.etaDisplay)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("· \(torrent.size.sizeString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .opacity(isPending ? 0.55 : 1)
    }
}

// MARK: - State Badge

private struct StateBadge: View {
    let state: TorrentState

    var body: some View {
        Label(state.displayName, systemImage: state.icon)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(state.color.opacity(0.15))
            .foregroundStyle(state.color)
            .clipShape(Capsule())
    }
}
