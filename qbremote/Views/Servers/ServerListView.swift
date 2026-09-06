//
//  ServerListView.swift
//  qbremote
//

import SwiftUI
import SwiftData

struct ServerListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \ServerProfile.createdAt) private var profiles: [ServerProfile]

    @Bindable var profilesVM: ServerProfilesViewModel
    @Binding var isShowingAddServer: Bool
    
    @State private var showToast = false
    @State private var toastMessage = ""

    @AppStorage("isDemoMode") private var isDemoMode: Bool = false

    /// Ephemeral profiles shown only in Demo Mode — never inserted into SwiftData.
    /// Held in `@State` (not rebuilt per render) so their `id`s stay stable and
    /// `ForEach` doesn't churn. The fixed UUIDs also keep store screenshots and
    /// snapshot references deterministic. Deliberately varied — HTTPS, a
    /// non-default port, and a port-less host — to exercise the row's URL
    /// formatting branches the way the test fixtures do.
    @State private var demoProfiles: [ServerProfile] = [
        ServerProfile(
            id: UUID(uuidString: "DE500000-0000-0000-0000-000000000001") ?? UUID(),
            name: "Demo Server", host: "demo.local", port: 8080, isActive: true
        ),
        ServerProfile(
            id: UUID(uuidString: "DE500000-0000-0000-0000-000000000002") ?? UUID(),
            name: "Home NAS", host: "192.168.1.42", port: 8080
        ),
        ServerProfile(
            id: UUID(uuidString: "DE500000-0000-0000-0000-000000000003") ?? UUID(),
            name: "Seedbox", host: "seedbox.example.com", port: 443, useHTTPS: true
        ),
        ServerProfile(
            id: UUID(uuidString: "DE500000-0000-0000-0000-000000000004") ?? UUID(),
            name: "Office Rack", host: "10.0.0.15", port: 9091
        ),
        ServerProfile(
            id: UUID(uuidString: "DE500000-0000-0000-0000-000000000005") ?? UUID(),
            name: "Media Server", host: "media.lan", port: nil
        )
    ]

    var body: some View {
        List {
            if isDemoMode {
                Section {
                    ForEach(demoProfiles) { profile in
                        ServerRowView(
                            profile: profile,
                            isActive: profile.isActive,
                            connectionStatus: .connected
                        ) {
                            // Do nothing on tap in demo mode
                        }
                    }
                } footer: {
                    Text("You are currently in Demo Mode. To view your real servers, disable Demo Mode in Settings.")
                }
            } else if profiles.isEmpty {
                ContentUnavailableView(
                    "No Servers",
                    systemImage: "server.rack",
                    description: Text("Add a qBittorrent server to get started.")
                )
            } else {
                ForEach(profiles) { profile in
                    ServerRowView(
                        profile: profile,
                        isActive: profile.isActive,
                        connectionStatus: profile.isActive ? profilesVM.activeConnectionStatus : .idle
                    ) {
                        profilesVM.setActive(profile, in: profiles)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    Color.primary
                        .mask {
                            Image("AppLogo")
                                .resizable()
                                .scaledToFit()
                                .colorInvert()
                                .luminanceToAlpha()
                        }
                        .frame(width: 80, height: 80)
                        .opacity(0.15)
                        .padding(.bottom, 60)
                }
            }
        }
        .navigationTitle("Servers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isShowingAddServer = true } label: {
                    Label("Add Server", systemImage: "plus")
                }
                .accessibilityIdentifier("add_server_button")
            }
        }
        .overlay(alignment: .bottom) {
            if showToast {
                Text(toastMessage)
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .foregroundStyle(.white)
                    .cornerRadius(8)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: profilesVM.activeConnectionStatus) { _, newValue in
            if case .error(let msg) = newValue {
                toastMessage = msg
                withAnimation { showToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { showToast = false }
                }
            }
        }
        .onAppear {
            profilesVM.setModelContext(modelContext)
            if let active = profilesVM.activeProfile(from: profiles), profilesVM.activeConnectionStatus == .idle {
                profilesVM.verifyActiveConnection(for: active)
            }
        }
    }
}

// MARK: - Row

private struct ServerRowView: View {
    let profile: ServerProfile
    let isActive: Bool
    let connectionStatus: ServerProfilesViewModel.ActiveConnectionStatus
    let onTap: () -> Void

    @State private var showEdit = false
    @State private var showConfig = false

    /// Falls back to the host when a profile has no name — the empty-name case
    /// the snapshot fixtures deliberately cover.
    private var displayName: String {
        profile.name.isEmpty ? profile.host : profile.name
    }

    private var displayURL: String {
        let scheme = profile.useHTTPS ? "https" : "http"
        if let port = profile.port {
            return "\(scheme)://\(profile.host):\(String(port))"
        } else {
            return "\(scheme)://\(profile.host)"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.title3)
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                .frame(width: 38, height: 38)
                .background(
                    (isActive ? Color.accentColor : Color.secondary).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text(displayURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if isActive {
                    statusBadge
                }
            }

            Spacer(minLength: 4)

            // 44x44 hit areas (HIG minimum) — the glyphs stay their original
            // size, contentShape just widens the tappable region around them.
            // Grouped in their own zero-spacing HStack so the outer spacing
            // doesn't add another gap here and squeeze the URL text.
            HStack(spacing: 0) {
                Button {
                    showConfig = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.secondary)
                        .imageScale(.medium)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("row_config_button")
                .accessibilityLabel("Server settings")

                Button {
                    showEdit = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(.blue)
                        .imageScale(.medium)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("row_edit_button")
                .accessibilityLabel("Edit server")
            }
        }
        .padding(.vertical, 10)
        .padding(.leading, 12)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(isActive ? 0.45 : 0), lineWidth: 1.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(perform: onTap)
        // Let the cards float over the view's own grouped background + watermark
        // instead of sitting in the List's default inset-grouped chrome.
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .sheet(isPresented: $showEdit) {
            NavigationStack {
                ServerEditView(profile: profile, isNew: false)
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showConfig) {
            ServerPreferencesView(profile: profile)
        }
    }

    // MARK: - Status

    /// Capsule badge matching the torrent-state idiom in `TorrentRowView`.
    /// Replaces the bare status glyph the row used to show — same information,
    /// but legible at a glance and readable by VoiceOver.
    private var statusBadge: some View {
        let label: String
        let icon: String
        let color: Color

        switch connectionStatus {
        case .idle:       label = "Connected";  icon = "checkmark.circle.fill";        color = .green
        case .connecting: label = "Connecting"; icon = "arrow.triangle.2.circlepath";  color = .yellow
        case .connected:  label = "Connected";  icon = "checkmark.circle.fill";        color = .green
        case .error:      label = "Error";      icon = "xmark.circle.fill";            color = .red
        }

        // An explicit HStack rather than a Label: under width pressure Label
        // adaptively drops its title and renders icon-only, and before that it
        // hyphenates mid-word ("Connect-ed"). fixedSize pins it to its ideal
        // width so neither happens.
        return HStack(spacing: 4) {
            Image(systemName: icon)
            Text(label)
        }
            .font(.caption2)
            .fontWeight(.medium)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .symbolEffect(.rotate, isActive: connectionStatus == .connecting)
            .padding(.top, 2)
    }
}
