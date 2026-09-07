//
//  TorrentFilterSheetView.swift
//  qbremote
//
//

import SwiftUI

struct TorrentFilterSheetView: View {
    @Bindable var browsing: TorrentBrowsing
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: Active Filters Summary
                Section {
                    Button("Clear All Filters", role: .destructive) {
                        browsing.clearFilters()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(!browsing.hasActiveFilters)
                }
                
                // MARK: Category Filter
                Section("Category") {
                    Picker("Category", selection: $browsing.activeCategoryFilter) {
                        Text("Any").tag(String?.none)
                        Text("None").tag(String?.some(""))
                        ForEach(browsing.availableCategories, id: \.self) { cat in
                            Text(cat).tag(String?.some(cat))
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // MARK: Tags Filter
                Section {
                    if browsing.availableTags.isEmpty {
                        Text("No tags available")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Match Mode", selection: $browsing.tagFilterMatchAll) {
                            Text("Match All").tag(true)
                            Text("Match Any").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, 4)
                        
                        ForEach(browsing.availableTags, id: \.self) { tag in
                            Toggle(tag, isOn: Binding(
                                get: { browsing.activeTagFilters.contains(tag) },
                                set: { isOn in
                                    if isOn {
                                        browsing.activeTagFilters.insert(tag)
                                    } else {
                                        browsing.activeTagFilters.remove(tag)
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
                    Picker("Location", selection: $browsing.activeLocationFilter) {
                        Text("Any").tag(String?.none)
                        ForEach(browsing.availableLocations, id: \.self) { loc in
                            Text(loc).tag(String?.some(loc))
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // MARK: Tracker Filter
                Section("Tracker") {
                    Picker("Tracker", selection: $browsing.activeTrackerFilter) {
                        Text("Any").tag(String?.none)
                        Text("None").tag(String?.some(""))
                        ForEach(browsing.availableTrackers, id: \.self) { tracker in
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
    }
}
