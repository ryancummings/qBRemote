//
//  IPadSplitView.swift
//  qbremote
//

import SwiftUI

struct IPadSplitView: View {
    @Binding var sidebarSelection: RootView.Tab?
    @Bindable var torrentVM: TorrentListViewModel
    @Bindable var profilesVM: ServerProfilesViewModel
    @Binding var showAddServer: Bool
    var activeProfile: ServerProfile?

    var body: some View {
        NavigationSplitView {
            List(RootView.Tab.allCases, id: \.self, selection: $sidebarSelection) { tab in
                tab.label
            }
            .navigationTitle("qBRemote")
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemBackground))
            .safeAreaInset(edge: .bottom) {
                SidebarFooterGraphic(torrentVM: torrentVM, activeProfile: activeProfile)
            }
        } detail: {
            switch sidebarSelection ?? .torrents {
            case .torrents:
                NavigationStack {
                    TorrentListView(torrentVM: torrentVM)
                }
            case .servers:
                NavigationStack {
                    ServerListView(profilesVM: profilesVM, isShowingAddServer: $showAddServer)
                }
            case .settings:
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .sheet(isPresented: $showAddServer) {
            NavigationStack {
                ServerEditView(profile: nil, isNew: true)
            }
            .presentationDragIndicator(.visible)
        }
    }
}
