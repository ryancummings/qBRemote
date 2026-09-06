//
//  TorrentFilterSheetView.swift
//  qbremote
//
//

import SwiftUI

struct TorrentFilterSheetView: View {
    @Bindable var torrentVM: TorrentListViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var availableCategories: [String] = []
    @State private var availableTags: [String] = []
    @State private var availableLocations: [String] = []
    @State private var availableTrackers: [String] = []

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Active Filters Summary
                Section {
                    Button("Clear All Filters", role: .destructive) {
                        torrentVM.activeCategoryFilter = nil
                        torrentVM.activeTagFilters.removeAll()
                        torrentVM.activeLocationFilter = nil
                        torrentVM.activeTrackerFilter = nil
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(!hasActiveFilters)
                }
                
                // MARK: Category Filter
                Section("Category") {
                    Picker("Category", selection: $torrentVM.activeCategoryFilter) {
                        Text("Any").tag(String?.none)
                        Text("None").tag(String?.some(""))
                        ForEach(availableCategories, id: \.self) { cat in
                            Text(cat).tag(String?.some(cat))
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // MARK: Tags Filter
                Section {
                    if availableTags.isEmpty {
                        Text("No tags available")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Match Mode", selection: $torrentVM.tagFilterMatchAll) {
                            Text("Match All").tag(true)
                            Text("Match Any").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, 4)
                        
                        ForEach(availableTags, id: \.self) { tag in
                            Toggle(tag, isOn: Binding(
                                get: { torrentVM.activeTagFilters.contains(tag) },
                                set: { isOn in
                                    if isOn {
                                        torrentVM.activeTagFilters.insert(tag)
                                    } else {
                                        torrentVM.activeTagFilters.remove(tag)
                                    }
                                }
                            ))
                        }
                    }
                } header: {
                    Text("Tags")
                } footer: {
                    Text("If no tags are checked, no tag filtering is applied.")
                }
                
                // MARK: Location Filter
                Section("Download Location") {
                    Picker("Location", selection: $torrentVM.activeLocationFilter) {
                        Text("Any").tag(String?.none)
                        ForEach(availableLocations, id: \.self) { loc in
                            Text(loc).tag(String?.some(loc))
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // MARK: Tracker Filter
                Section("Tracker") {
                    Picker("Tracker", selection: $torrentVM.activeTrackerFilter) {
                        Text("Any").tag(String?.none)
                        Text("None").tag(String?.some(""))
                        ForEach(availableTrackers, id: \.self) { tracker in
                            Text(tracker).tag(String?.some(tracker))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Advanced Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            let base = torrentVM.torrents
            
            let cats = Set(base.map { $0.category }.filter { !$0.isEmpty })
            availableCategories = Array(cats).sorted()
            
            var tags = Set<String>()
            for torrent in base {
                let split = torrent.tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                tags.formUnion(split)
            }
            availableTags = Array(tags).sorted()
            
            let locs = Set(base.map { $0.savePath }.filter { !$0.isEmpty })
            availableLocations = Array(locs).sorted()
            
            let trackers = Set(base.map { $0.tracker }.filter { !$0.isEmpty })
            availableTrackers = Array(trackers).sorted()
        }
    }
    
    // MARK: - Computed Properties for Available Options
    
    private var hasActiveFilters: Bool {
        torrentVM.activeCategoryFilter != nil ||
        !torrentVM.activeTagFilters.isEmpty ||
        torrentVM.activeLocationFilter != nil ||
        torrentVM.activeTrackerFilter != nil
    }
}
