//
//  RootView.swift
//  qbremote
//

import SwiftUI
import SwiftData

struct IncomingURLAction: Identifiable {
    let id = UUID()
    let url: URL
}

struct RootView: View {
    @AppStorage("isDemoMode") private var isDemoMode: Bool = false
    @Query(sort: \ServerProfile.createdAt) private var profiles: [ServerProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    @State private var torrentVM = TorrentListViewModel()
    @State private var profilesVM = ServerProfilesViewModel()
    @State private var selectedTab: Tab = .torrents
    @State private var showAddServer = false
    @State private var showSettings = false
    @State private var showTipJarSheet = false
    @State private var incomingAction: IncomingURLAction?
    
    @AppStorage("showTipJarPopup") private var showTipJarPopup: Bool = true
    @AppStorage("appLaunchCount") private var appLaunchCount: Int = 0

    // iPad sidebar selection
    @State private var sidebarSelection: Tab? = .torrents

    enum Tab: String, CaseIterable {
        case torrents, servers, settings

        var label: some View {
            switch self {
            case .torrents: return Label("Torrents", systemImage: "arrow.down.circle.fill")
            case .servers:  return Label("Servers",  systemImage: "server.rack")
            case .settings: return Label("Settings", systemImage: "gear")
            }
        }
    }

    var activeProfile: ServerProfile? {
        if isDemoMode {
            return ServerProfile(name: "Demo", host: "demo.local", port: 8080, username: "demo", isActive: true)
        }
        return profiles.first(where: { $0.isActive }) ?? profiles.first
    }

    var body: some View {
        Group {
            if profiles.isEmpty && !isDemoMode {
                onboardingView
            } else {
                adaptiveNavigation
            }
        }
        .onChange(of: activeProfile?.lastUpdated) { _, _ in
            reconnect()
        }
        .onChange(of: activeProfile?.baseURL) { _, _ in
            reconnect()
        }
        .onChange(of: isDemoMode) { _, newValue in
            if newValue {
                showSettings = false
            }
            reconnect()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:      if !isDemoMode { torrentVM.startPolling() }
            case .background, .inactive: torrentVM.stopPolling()
            @unknown default:  break
            }
        }
        .onAppear {
            profilesVM.setModelContext(modelContext)
            reconnect()
            
            let isUITest = ProcessInfo.processInfo.arguments.contains("-isUITest")
            if !isUITest && !isDemoMode {
                appLaunchCount += 1
                if showTipJarPopup && appLaunchCount >= 5 && appLaunchCount % 5 == 0 {
                    // Delay slightly to allow onOpenURL to trigger first
                    Task {
                        try? await Task.sleep(for: .seconds(0.5))
                        if incomingAction == nil {
                            showTipJarSheet = true
                        }
                    }
                }
            }
        }
        .onOpenURL { url in
            incomingAction = IncomingURLAction(url: url)
        }
        .sheet(item: $incomingAction) { action in
            NavigationStack {
                ExternalAddTorrentFlowView(
                    url: action.url,
                    profiles: profiles,
                    onDismiss: {
                        incomingAction = nil
                        Task { await torrentVM.fetchAll() }
                    }
                )
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTipJarSheet) {
            TipJarView()
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Onboarding

    private var onboardingView: some View {
        NavigationStack {
            ContentUnavailableView {
                Label {
                    Text("No Server Configured")
                } icon: {
                    Color.primary
                        .mask {
                            Image("AppLogo")
                                .resizable()
                                .scaledToFit()
                                .colorInvert()
                                .luminanceToAlpha()
                        }
                        .frame(width: 80, height: 80)
                }
            } description: {
                Text("Add your qBittorrent server to get started.")
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Server") { showAddServer = true }
                }
            }
        }
        .sheet(isPresented: $showAddServer) {
            NavigationStack {
                ServerEditView(profile: nil, isNew: true)
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showSettings = false }
                        }
                    }
            }
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Adaptive Navigation (iPhone: TabView, iPad: NavigationSplitView)

    @ViewBuilder
    private var adaptiveNavigation: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            IPadSplitView(
                sidebarSelection: $sidebarSelection,
                torrentVM: torrentVM,
                profilesVM: profilesVM,
                showAddServer: $showAddServer,
                activeProfile: activeProfile
            )
        } else {
            IPhoneTabView(
                selectedTab: $selectedTab,
                torrentVM: torrentVM,
                profilesVM: profilesVM,
                showAddServer: $showAddServer
            )
        }
    }

    // MARK: - Connection

    private func reconnect() {
        if isDemoMode {
            let demoProfile = ServerProfile(name: "Demo", host: "demo.local", port: 8080, username: "demo", isActive: true)
            torrentVM.configure(with: demoProfile, injectedService: MockQBittorrentAPIService())
            Task {
                torrentVM.connectionStatus = .connected
                torrentVM.torrents = MockQBittorrentAPIService.sharedMockTorrents
                torrentVM.stats = GlobalStats(downloadSpeed: 3_000_000, uploadSpeed: 2_000_000, downloadedData: 10_000_000_000, uploadedData: 5_000_000_000)
                torrentVM.isLoading = false
            }
            return
        }

        guard let profile = activeProfile else {
            torrentVM.stopPolling()
            return
        }
        
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-isUITest") {
            torrentVM.configure(with: profile, injectedService: MockQBittorrentAPIService())
            // Simulate start behavior for UI tests without real polling
            Task {
                torrentVM.connectionStatus = .connected
                torrentVM.torrents = MockQBittorrentAPIService.sharedMockTorrents
                torrentVM.stats = GlobalStats(downloadSpeed: 3_000_000, uploadSpeed: 2_000_000, downloadedData: 10_000_000_000, uploadedData: 5_000_000_000)
                torrentVM.isLoading = false
            }
            return
        }
#endif
        
        torrentVM.configure(with: profile)
        Task { await torrentVM.start(profile: profile) }
    }
}

