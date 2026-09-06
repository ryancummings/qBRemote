//
//  ServerEditView.swift
//  qbremote
//

import SwiftUI
import SwiftData

struct ServerEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Local copy so we can preserve it if we save but don't dismiss
    @State private var profile: ServerProfile?
    @State private var isNew: Bool

    init(profile: ServerProfile?, isNew: Bool) {
        self._profile = State(initialValue: profile)
        self._isNew = State(initialValue: isNew)
    }

    // Local form state
    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = ""
    @State private var username: String = "admin"
    @State private var password: String = ""
    @State private var useHTTPS: Bool = false
    @State private var allowUntrustedSSL: Bool = false
    @State private var pollingInterval: Double = 5.0

    @State private var profilesVM = ServerProfilesViewModel()
    @State private var isTestingConnection = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        List {
            // MARK: Connection
            Section {
                TextField("Name (e.g., My Server)", text: $name)
                    .textContentType(.name)
                    .submitLabel(.next)
                    .accessibilityIdentifier("server_name_field")

                TextField("Host (192.168.1.100 or myserver.com)", text: $host)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .textContentType(.URL)
                    .submitLabel(.next)
                    .accessibilityIdentifier("server_host_field")

                TextField("Port (Optional)", text: $port)
                    .keyboardType(.numberPad)
                    .submitLabel(.next)
                    .accessibilityIdentifier("server_port_field")

                Toggle("Use HTTPS", isOn: $useHTTPS)
                if useHTTPS {
                    Toggle("Allow Untrusted SSL", isOn: $allowUntrustedSSL)
                }
            } header: {
                Text("Connection")
            } footer: {
                Text("Enter the IP address or domain name. Do not include http:// or https://")
            }

            // MARK: Credentials
            Section("Credentials") {
                TextField("Username", text: $username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .textContentType(.username)
                    .submitLabel(.next)

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .submitLabel(.done)
            }

            // MARK: Polling
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Refresh Interval")
                        Spacer()
                        Text("\(Int(pollingInterval))s")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $pollingInterval, in: 2...60, step: 1)
                }
            } header: {
                Text("Polling")
            } footer: {
                Text("How often the app checks for torrent updates.")
            }

            // MARK: Test Connection
            Section {
                Button {
                    testConnection()
                } label: {
                    HStack {
                        if isTestingConnection {
                            ProgressView()
                                .padding(.trailing, 4)
                        }
                        Text(isTestingConnection ? "Testing…" : "Test Connection")
                    }
                }
                .accessibilityIdentifier("test_connection_button")
                .disabled(host.isEmpty || isTestingConnection)

                // Result feedback
                switch profilesVM.connectionTestResult {
                case .success(let msg):
                    Label(msg, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .failure(let msg):
                    Label(msg, systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .lineLimit(3)
                default:
                    EmptyView()
                }
            }
            
            // MARK: Delete Server
            if !isNew {
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Server")
                            Spacer()
                        }
                    }
                    .accessibilityIdentifier("delete_server_button")
                }
            }
        }
        .alert("Delete Server", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let profile = profile {
                    profilesVM.delete(profile: profile)
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to delete this server profile?")
        }
        .navigationTitle(isNew ? "Add Server" : "Edit Server")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(host.isEmpty || username.isEmpty)
                    .accessibilityIdentifier("save_server_button")
            }
        }
        .onAppear {
            profilesVM.setModelContext(modelContext)
            populateFromProfile()
        }
        .presentationSizing(.form)
    }

    // MARK: - Helpers

    private func populateFromProfile() {
        guard let p = profile else { return }
        name            = p.name
        host            = p.host
        if let pPort = p.port {
            port = String(pPort)
        } else {
            port = ""
        }
        username        = p.username
        useHTTPS        = p.useHTTPS
        allowUntrustedSSL = p.allowUntrustedSSL
        pollingInterval = p.pollingInterval
        password        = KeychainService.loadPassword(for: p.id) ?? ""
    }

    private func testConnection() {
        // Save the profile first, update our local reference if it's new
        save(dismissAfter: false)

        profilesVM.resetTestResult()
        isTestingConnection = true
        Task {
            await profilesVM.testConnection(
                host: host,
                port: Int(port),
                useHTTPS: useHTTPS,
                allowUntrustedSSL: allowUntrustedSSL,
                username: username,
                password: password
            )
            isTestingConnection = false
        }
    }

    private func save(dismissAfter: Bool = true) {
        let portInt = Int(port)
        if let existing = profile {
            existing.name            = name
            existing.host            = host
            existing.port            = portInt
            existing.username        = username
            existing.useHTTPS        = useHTTPS
            existing.allowUntrustedSSL = allowUntrustedSSL
            existing.pollingInterval = pollingInterval
            profilesVM.save(profile: existing, password: password)
        } else {
            let newProfile = ServerProfile(
                name: name,
                host: host,
                port: portInt,
                username: username,
                useHTTPS: useHTTPS,
                pollingInterval: pollingInterval,
                allowUntrustedSSL: allowUntrustedSSL
            )
            profilesVM.insertNew(newProfile, password: password)
            self.profile = newProfile
            self.isNew = false
        }
        if dismissAfter {
            dismiss()
        }
    }
}
