//
//  SettingsView.swift
//  qbremote
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("themePreference") private var themePreference: AppTheme = .system
    @AppStorage("isDemoMode") private var isDemoMode: Bool = false
    @AppStorage("isDeveloperUnlocked") private var isDeveloperUnlocked: Bool = false
    @AppStorage("showTipJarPopup") private var showTipJarPopup: Bool = true
    @State private var versionTapCount: Int = 0
    @State private var showTipJarSheet = false

    var body: some View {
        List {
            Section("Appearance") {
                Picker("Theme", selection: $themePreference) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
            }

            Section("Support") {
                Toggle("Show Tip Jar on Launch", isOn: $showTipJarPopup)
                Button("Tip Jar") {
                    showTipJarSheet = true
                }
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    .contentShape(Rectangle())
                    .onTapGesture {
                        versionTapCount += 1
                        if versionTapCount >= 5 {
                            withAnimation {
                                isDeveloperUnlocked = true
                            }
                        }
                    }
                
                if isDeveloperUnlocked || isDemoMode {
                    Toggle("Demo Mode", isOn: $isDemoMode)
                        .accessibilityIdentifier("demo_mode_toggle")
                }

                LabeledContent("API", value: "qBittorrent WebUI v5.0")
                Link("qBittorrent API Reference", destination: URL(string: "https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-(qBittorrent-5.0)")!)
            }
        }
        .navigationTitle("Settings")
        .preferredColorScheme(themePreference.colorScheme)
        .sheet(isPresented: $showTipJarSheet) {
            TipJarView()
                .presentationDragIndicator(.visible)
        }
    }
}
