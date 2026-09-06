//
//  ConnectionStatusView.swift
//  qbremote
//

import SwiftUI

// MARK: - Toolbar Button

struct ConnectionStatusView: View {
    let torrentVM: TorrentListViewModel

    @State private var showDetail = false
    @State private var animating = false  // drives the repeating ring pulse

    private var statusColor: Color {
        switch torrentVM.connectionStatus {
        case .connecting: return .orange
        case .connected:  return .green
        case .error:      return .red
        }
    }

    /// Only connecting/error should have a continuous pulse
    private var shouldPulse: Bool {
        if case .connected = torrentVM.connectionStatus { return false }
        return true
    }

    var body: some View {
        Button {
            showDetail = true
        } label: {
            HStack(spacing: 8) {
                // Solid inner dot — enlarged for visibility
                Circle()
                    .fill(statusColor)
                    .frame(width: 14, height: 14)
                    // Pulsing ring lives in overlay so it NEVER affects layout
                    .overlay {
                        Circle()
                            .stroke(statusColor, lineWidth: 1.5)
                            .scaleEffect(animating ? 2.4 : 1.0)
                            .opacity(animating ? 0 : 0.75)
                            .animation(
                                shouldPulse
                                    ? .easeOut(duration: 1.3).repeatForever(autoreverses: false)
                                    : .none,
                                value: animating
                            )
                    }
                    // Breathe animation on every polling event
                    .phaseAnimator([0, 1, 0], trigger: torrentVM.lastUpdated) { content, phase in
                        content
                            .scaleEffect(phase == 1 ? 1.3 : 1.0)
                            .opacity(phase == 1 ? 0.6 : 1.0)
                    } animation: { phase in
                        .easeInOut(duration: 0.6)
                    }
                
                if !torrentVM.activeServerName.isEmpty {
                    Text(torrentVM.activeServerName)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 140, alignment: .leading)
                }
            }
        }
        .sheet(isPresented: $showDetail) {
            ConnectionDetailSheet(torrentVM: torrentVM)
        }
        .onAppear { resetAnimation() }
        .onChange(of: torrentVM.connectionStatus) { _, _ in
            // Reset then re-trigger so RepeatForever restarts cleanly on status changes
            animating = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                resetAnimation()
            }
        }
    }

    private func resetAnimation() {
        animating = shouldPulse
    }
}

// MARK: - Detail Sheet

private struct ConnectionDetailSheet: View {
    let torrentVM: TorrentListViewModel
    @Environment(\.dismiss) private var dismiss

    private var relativeUpdate: String {
        guard let date = torrentVM.lastUpdated else { return "Never" }
        let secs = Int(Date.now.timeIntervalSince(date))
        if secs < 5  { return "Just now" }
        if secs < 60 { return "\(secs)s ago" }
        return "\(secs / 60)m ago"
    }

    var body: some View {
        NavigationStack {
            List {
                // Status header
                Section {
                    HStack(spacing: 14) {
                        statusDot
                        VStack(alignment: .leading, spacing: 3) {
                            Text(statusTitle)
                                .font(.headline)
                            Text(torrentVM.connectionStatus.label)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Server info
                Section("Server") {
                    DetailRow(label: "Name", value: torrentVM.activeServerName)
                    DetailRow(label: "URL",  value: torrentVM.activeServerURL)
                    if let updated = torrentVM.lastUpdated {
                        DetailRow(label: "Last Updated", value: updated.formatted(date: .omitted, time: .shortened) + " (\(relativeUpdate))")
                    }
                }

                // Retry / action
                if case .error = torrentVM.connectionStatus {
                    Section {
                        Button {
                            dismiss()
                            Task { await torrentVM.fetchAll() }
                        } label: {
                            Label("Retry Connection", systemImage: "arrow.clockwise")
                        }
                    }
                }
            }
            .navigationTitle("Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationSizing(.form)
    }

    private var statusTitle: String {
        switch torrentVM.connectionStatus {
        case .connecting: return "Connecting…"
        case .connected:  return "Connected"
        case .error:      return "Connection Error"
        }
    }

    private var statusColor: Color {
        switch torrentVM.connectionStatus {
        case .connecting: return .orange
        case .connected:  return .green
        case .error:      return .red
        }
    }

    @ViewBuilder
    private var statusDot: some View {
        ZStack {
            Circle().fill(statusColor.opacity(0.2)).frame(width: 36, height: 36)
            Circle().fill(statusColor).frame(width: 16, height: 16)
        }
    }
}

// MARK: - Row helper

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing).lineLimit(2)
        }
    }
}
