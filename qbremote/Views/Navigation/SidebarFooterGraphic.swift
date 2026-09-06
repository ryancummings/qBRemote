//
//  SidebarFooterGraphic.swift
//  qbremote
//

import SwiftUI

struct SidebarFooterGraphic: View {
    var torrentVM: TorrentListViewModel
    var activeProfile: ServerProfile?

    @State private var rotation: Double = 0
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background circle
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 90, height: 90)
                // Main Icon
                Image(systemName: "server.rack")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 45, height: 45)
                    .foregroundStyle(statusColor)
                
                // Status Overlay
                if torrentVM.connectionStatus == .connecting {
                    Circle()
                        .trim(from: 0, to: 0.15)
                        .stroke(Color.yellow, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 110, height: 110)
                        .rotationEffect(.degrees(rotation))
                        .onAppear {
                            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                rotation = 360
                            }
                        }
                } else if torrentVM.connectionStatus == .connected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 26))
                        .background(Circle().fill(Color(uiColor: .systemBackground)))
                        .offset(x: 35, y: 35)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 26))
                        .background(Circle().fill(Color(uiColor: .systemBackground)))
                        .offset(x: 35, y: 35)
                }
            }
            .padding(.top, 24)
            
            VStack(spacing: 8) {
                if let profile = activeProfile {
                    Text(profile.name.isEmpty ? "Connected" : profile.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(statusColor)
                        .lineLimit(1)
                } else {
                    Text("No server")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Text(torrentVM.connectionStatus.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            if torrentVM.connectionStatus == .connected, let stats = torrentVM.stats {
                HStack(spacing: 16) {
                    Label(stats.downloadSpeed.speedString, systemImage: "arrow.down")
                        .foregroundStyle(.blue)
                    
                    Label(stats.uploadSpeed.speedString, systemImage: "arrow.up")
                        .foregroundStyle(.green)
                }
                .font(.subheadline.weight(.medium))
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 40)
        .padding(.horizontal, 16)
        .background(
            LinearGradient(
                colors: [Color(uiColor: .systemBackground), Color(uiColor: .systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var statusColor: Color {
        switch torrentVM.connectionStatus {
        case .connecting: return .yellow
        case .connected: return .green
        case .error: return .red
        }
    }
}
