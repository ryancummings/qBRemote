//
//  TorrentListView.swift
//  qbremote
//

import SwiftUI
import SwiftData

struct TorrentListView: View {
    @Query(sort: \ServerProfile.createdAt) private var profiles: [ServerProfile]

    @Bindable var torrentVM: TorrentListViewModel
    @State private var selectedTorrent: Torrent?
    @State private var showAddTorrent = false
    @State private var showFilterSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Fixed Top Bar explicitly in layout instead of relying on safeAreaInset which is buggy with ScrollViews on iOS 17
            VStack(spacing: 0) {
                FilterPickerView(
                    activeFilter: $torrentVM.activeFilter,
                    connectionStateID: "\(torrentVM.activeServerURL)-\(torrentVM.connectionStatus.label)"
                )
                Divider()
            }
            .background(.bar)

            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if UIDevice.current.userInterfaceIdiom != .pad, let stats = torrentVM.stats {
                HStack(spacing: 16) {
                    Label("DL: \(stats.downloadSpeed.speedString)", systemImage: "arrow.down")
                        .foregroundStyle(.blue)
                    
                    Label("UP: \(stats.uploadSpeed.speedString)", systemImage: "arrow.up")
                        .foregroundStyle(.green)
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    Text("\(torrentVM.filteredTorrents.count) torrents")
                        .foregroundStyle(.secondary)
                }
                .font(.caption.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                .padding(.bottom, 8)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $torrentVM.searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search torrents")
        .toolbar {
            // Connection status dot — top-left
            ToolbarItem(placement: .navigationBarLeading) {
                ConnectionStatusView(torrentVM: torrentVM)
            }

            // Primary Actions — top-right (Sort, Add)
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Picker("Sort By", selection: $torrentVM.activeSortOption) {
                        ForEach(TorrentSortOption.allCases) { option in
                            Label(option.rawValue, systemImage: option.icon)
                                .tag(option)
                        }
                    }
                    
                    Divider()
                    
                    Button {
                        torrentVM.sortAscending.toggle()
                    } label: {
                        Label(torrentVM.sortAscending ? "Ascending" : "Descending",
                              systemImage: torrentVM.sortAscending ? "arrow.up" : "arrow.down")
                    }
                } label: {
                    Label("Sort Torrents", systemImage: "arrow.up.arrow.down")
                }
                
                Button { showFilterSheet = true } label: {
                    let hasActiveFilters = torrentVM.activeCategoryFilter != nil || !torrentVM.activeTagFilters.isEmpty || torrentVM.activeLocationFilter != nil || torrentVM.activeTrackerFilter != nil
                    Label("Advanced Filters", systemImage: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                
                Button { showAddTorrent = true } label: {
                    Label("Add Torrent", systemImage: "plus")
                }
            }
        }
        .sheet(item: $selectedTorrent) { torrent in
            NavigationStack {
                TorrentDetailView(
                    torrent: torrent,
                    session: torrentVM.serverSession,
                    onPause:  { Task { await torrentVM.pause(torrent: torrent) } },
                    onResume: { Task { await torrentVM.resume(torrent: torrent) } },
                    onDelete: { deleteFiles in Task { await torrentVM.delete(torrent: torrent, deleteFiles: deleteFiles) } },
                    onMove:   { location in Task { await torrentVM.move(torrent: torrent, to: location) } }
                )
            }
            .presentationDragIndicator(.visible)
            .presentationSizing(.page)
        }
        .sheet(isPresented: $showAddTorrent) {
            NavigationStack {
                AddTorrentView(session: torrentVM.sessionForAdding()) {
                    Task { await torrentVM.fetchAll() }
                }
            }
            .presentationDragIndicator(.visible)
            .presentationSizing(.form)
        }
        .sheet(isPresented: $showFilterSheet) {
            TorrentFilterSheetView(torrentVM: torrentVM)
                .presentationDragIndicator(.visible)
                .presentationSizing(.form)
        }
    }

    // MARK: - Main Content Layout 

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            if (torrentVM.isLoading || torrentVM.connectionStatus == .connecting) && torrentVM.error == nil {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    if torrentVM.connectionStatus == .connecting {
                        Text("Connecting to \(torrentVM.activeServerName.isEmpty ? "server" : torrentVM.activeServerName)…")
                            .font(.headline)
                        Text("Establishing connection")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else {
                        Text("Loading torrents…")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemBackground))
                .zIndex(1)

            } else if let errorMsg = torrentVM.error, torrentVM.torrents.isEmpty {
                connectionErrorView(errorMsg)
                    .zIndex(2)

            } else if torrentVM.filteredTorrents.isEmpty {
                // Empty state but filters still showed above
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: torrentVM.searchQuery.isEmpty ? "tray" : "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(torrentVM.searchQuery.isEmpty
                         ? "No \(torrentVM.activeFilter == .all ? "" : torrentVM.activeFilter.rawValue.lowercased() + " ")torrents"
                         : "No results for \"\(torrentVM.searchQuery)\"")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)

            } else {
                torrentList
            }
        }
        .refreshable {
            await torrentVM.fetchAll()
        }
    }

    // MARK: - Connection Error View

    @ViewBuilder
    private func connectionErrorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Connection Error")
                .font(.title2)
                .fontWeight(.semibold)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await torrentVM.fetchAll() }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - List

    private var torrentList: some View {
        List {
            // Non-fatal error banner (stale data still showing)
            if let errorMsg = torrentVM.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(errorMsg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.orange.opacity(0.1))
            }

            ForEach(torrentVM.filteredTorrents) { torrent in
                Button {
                    selectedTorrent = torrent
                } label: {
                    TorrentRowView(
                        torrent: torrent,
                        isPending: torrentVM.pendingHashes.contains(torrent.hash)
                    )
                }
                .accessibilityIdentifier("torrent_row_\(torrent.name)")
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
    }

}

struct FilterPickerView: View {
    @Binding var activeFilter: TorrentFilter
    let connectionStateID: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Lead-in spacer for consistent padding when resetting scroll
                    Color.clear
                        .frame(width: 8) // 8 (frame) + 8 (HStack spacing) = 16px padding
                        .id("FILTER_START")
                    
                    ForEach(TorrentFilter.allCases, id: \.self) { filter in
                        FilterChip(
                            title: filter.rawValue,
                            icon: filter.icon,
                            isSelected: activeFilter == filter
                        ) {
                            activeFilter = filter
                        }
                        .id(filter)
                    }
                    
                    Color.clear
                        .frame(width: 16)
                }
            }
            .frame(height: 52)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .contentShape(Rectangle())
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onChange(of: geo.size.width) { _, _ in
                            // Smoothly scroll back to start instead of recreating view with .id()
                            withAnimation(.spring(duration: 0.3)) {
                                proxy.scrollTo("FILTER_START", anchor: .leading)
                            }
                        }
                }
            }
            .onChange(of: connectionStateID) { _, _ in
                // Also reset on server switch
                withAnimation(.spring(duration: 0.3)) {
                    proxy.scrollTo("FILTER_START", anchor: .leading)
                }
            }
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.primary.opacity(0.1))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
