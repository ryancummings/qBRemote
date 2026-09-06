//
//  IPhoneTabView.swift
//  qbremote
//

import SwiftUI

struct IPhoneTabView: View {
    @Binding var selectedTab: RootView.Tab
    @Bindable var torrentVM: TorrentListViewModel
    @Bindable var profilesVM: ServerProfilesViewModel
    @Binding var showAddServer: Bool

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TorrentListView(torrentVM: torrentVM)
            }
            .tag(RootView.Tab.torrents)
            .tabItem { RootView.Tab.torrents.label }

            NavigationStack {
                ServerListView(profilesVM: profilesVM, isShowingAddServer: $showAddServer)
            }
            .tag(RootView.Tab.servers)
            .tabItem { RootView.Tab.servers.label }

            NavigationStack {
                SettingsView()
            }
            .tag(RootView.Tab.settings)
            .tabItem { RootView.Tab.settings.label }
        }
        .sheet(isPresented: $showAddServer) {
            NavigationStack {
                ServerEditView(profile: nil, isNew: true)
            }
            .presentationDragIndicator(.visible)
        }
    }
}
