//
//  ServerPreferencesView.swift
//  qbremote
//

import SwiftUI
import SwiftData

struct ServerPreferencesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let profile: ServerProfile
    @State private var viewModel: ServerPreferencesViewModel
    @State private var showConnectivityWarning = false

    /// - Parameter viewModel: Injection seam for tests/previews. Pass a
    ///   pre-configured (already-loaded) view model to render a deterministic
    ///   state without waiting on the `onAppear` network load. Production call
    ///   sites omit it and get the default empty view model.
    init(profile: ServerProfile, viewModel: ServerPreferencesViewModel? = nil) {
        self.profile = profile
        self._viewModel = State(initialValue: viewModel ?? ServerPreferencesViewModel())
    }

    var body: some View {
        NavigationStack {
            Form {
                if viewModel.isLoading {
                    ProgressView("Loading preferences...")
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if viewModel.preferences != nil {
                    preferencesForm
                }
            }
            .navigationTitle("Server Config")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if viewModel.hasConnectionSettingsChanged {
                            showConnectivityWarning = true
                        } else {
                            performSave()
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .alert("Connectivity Warning", isPresented: $showConnectivityWarning) {
                Button("Cancel", role: .cancel) {}
                Button("Save and Reconnect", role: .destructive) {
                    performSave()
                }
            } message: {
                Text("You have changed connection settings (Web UI Port or HTTPS). If these are incorrect, you may lose connection to the server. Continue?")
            }
        }
        .onAppear {
            viewModel.configure(with: profile, context: modelContext)
            Task {
                await viewModel.loadPreferences()
            }
        }
        .presentationSizing(.form)
    }
    
    private func performSave() {
        Task {
            if await viewModel.savePreferences() {
                dismiss()
            }
        }
    }

    @ViewBuilder
    private var preferencesForm: some View {
        // Connection
        Section("Connection") {
            TextField("Listen Port", text: $viewModel.listenPortString)
                .keyboardType(.numberPad)
            
            Toggle("Use UPnP / NAT-PMP port forwarding from my router", isOn: Binding(
                get: { viewModel.preferences?.upnp ?? false },
                set: { viewModel.preferences?.upnp = $0 }
            ))
        }
        
        // Speed Limits
        Section("Global Speed Limits (0 = ∞)") {
            HStack {
                Text("Download:")
                TextField("0", text: $viewModel.dlLimitKBString)
                    .keyboardType(.numberPad)
                Text("KB/s")
            }
            HStack {
                Text("Upload:")
                TextField("0", text: $viewModel.upLimitKBString)
                    .keyboardType(.numberPad)
                Text("KB/s")
            }
        }
        
        // Alternative Rate Limits
        Section("Alternative Rate Limits") {
            Toggle("Schedule Alt Limits", isOn: Binding(
                get: { viewModel.preferences?.scheduler_enabled ?? false },
                set: { viewModel.preferences?.scheduler_enabled = $0 }
            ))
            
            if viewModel.preferences?.scheduler_enabled == true {
                DatePicker("From", selection: Binding(
                    get: {
                        var components = DateComponents()
                        components.hour = viewModel.preferences?.schedule_from_hour ?? 8
                        components.minute = viewModel.preferences?.schedule_from_min ?? 0
                        return Calendar.current.date(from: components) ?? Date()
                    },
                    set: { date in
                        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                        viewModel.preferences?.schedule_from_hour = components.hour
                        viewModel.preferences?.schedule_from_min = components.minute
                    }
                ), displayedComponents: .hourAndMinute)
                
                DatePicker("To", selection: Binding(
                    get: {
                        var components = DateComponents()
                        components.hour = viewModel.preferences?.schedule_to_hour ?? 20
                        components.minute = viewModel.preferences?.schedule_to_min ?? 0
                        return Calendar.current.date(from: components) ?? Date()
                    },
                    set: { date in
                        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                        viewModel.preferences?.schedule_to_hour = components.hour
                        viewModel.preferences?.schedule_to_min = components.minute
                    }
                ), displayedComponents: .hourAndMinute)
                
                Picker("Days", selection: Binding(
                    get: { viewModel.preferences?.schedule_days ?? 0 },
                    set: { viewModel.preferences?.schedule_days = $0 }
                )) {
                    Text("Everyday").tag(0)
                    Text("Weekday").tag(1)
                    Text("Weekend").tag(2)
                    Text("Monday").tag(3)
                    Text("Tuesday").tag(4)
                    Text("Wednesday").tag(5)
                    Text("Thursday").tag(6)
                    Text("Friday").tag(7)
                    Text("Saturday").tag(8)
                    Text("Sunday").tag(9)
                }
            }
            
            HStack {
                Text("Download:")
                TextField("∞", text: $viewModel.altDlLimitKBString)
                    .keyboardType(.numberPad)
                Text("KB/s")
            }
            HStack {
                Text("Upload:")
                TextField("∞", text: $viewModel.altUpLimitKBString)
                    .keyboardType(.numberPad)
                Text("KB/s")
            }
        }
        
        // Web UI
        Section(content: {
            TextField("Web UI Port", text: $viewModel.webUIPortString)
                .keyboardType(.numberPad)
            
            Toggle("Use HTTPS instead of HTTP", isOn: Binding(
                get: { viewModel.preferences?.use_https ?? false },
                set: { viewModel.preferences?.use_https = $0 }
            ))
        }, header: {
            Text("Web UI")
        }, footer: {
            if profile.useHTTPS {
                Text("Note: You are currently connected using HTTPS. Disabling this option on the server may cause connection loss unless properly configured.")
            } else {
                Text("Note: You are currently connected using HTTP. Enabling this option on the server may cause connection loss unless your SSL certificates are properly set up.")
            }
        })
        
        // BitTorrent
        Section("BitTorrent") {
            Toggle("Enable DHT (decentralized network)", isOn: Binding(
                get: { viewModel.preferences?.dht ?? false },
                set: { viewModel.preferences?.dht = $0 }
            ))
            Toggle("Enable PeX (Peer Exchange)", isOn: Binding(
                get: { viewModel.preferences?.pex ?? false },
                set: { viewModel.preferences?.pex = $0 }
            ))
            Toggle("Enable Local Peer Discovery", isOn: Binding(
                get: { viewModel.preferences?.lpd ?? false },
                set: { viewModel.preferences?.lpd = $0 }
            ))
            
            Picker("Encryption Mode", selection: Binding(
                get: { viewModel.preferences?.encryption ?? 0 },
                set: { viewModel.preferences?.encryption = $0 }
            )) {
                Text("Prefer Encryption").tag(0)
                Text("Force on").tag(1)
                Text("Force off").tag(2)
            }
        }
        
        // Downloads
        Section("Downloads") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Downloads Directory").font(.caption).foregroundStyle(.secondary)
                TextField("Default Save Path", text: Binding(
                    get: { viewModel.preferences?.save_path ?? "" },
                    set: { viewModel.preferences?.save_path = $0 }
                ))
            }
            
            Toggle("Append .!qB extension to incomplete files", isOn: Binding(
                get: { viewModel.preferences?.append_extension ?? false },
                set: { viewModel.preferences?.append_extension = $0 }
            ))
            
            Toggle("Pre-allocate disk space for all files", isOn: Binding(
                get: { viewModel.preferences?.preallocate_all ?? false },
                set: { viewModel.preferences?.preallocate_all = $0 }
            ))
        }
    }
}
