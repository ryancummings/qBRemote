//
//  ServerEditView.swift
//  qbremote
//

import SwiftUI
import SwiftData

struct ServerEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var draft: ServerProfileDraft
    @State private var testTask: Task<Void, Never>?
    @State private var showDeleteConfirmation = false

    init(profile: ServerProfile?, isNew: Bool) {
        self._draft = State(initialValue: ServerProfileDraft(profile: profile))
    }

    var body: some View {
        List {
            // MARK: Connection
            Section {
                TextField("Name (e.g., My Server)", text: $draft.name)
                    .textContentType(.name)
                    .submitLabel(.next)
                    .accessibilityIdentifier("server_name_field")

                TextField("Host (192.168.1.100 or myserver.com)", text: $draft.host)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .textContentType(.URL)
                    .submitLabel(.next)
                    .accessibilityIdentifier("server_host_field")

                TextField("Port (Optional)", text: $draft.port)
                    .keyboardType(.numberPad)
                    .submitLabel(.next)
                    .accessibilityIdentifier("server_port_field")

                Toggle("Use HTTPS", isOn: $draft.useHTTPS)
                if draft.useHTTPS {
                    Toggle("Allow Untrusted SSL", isOn: $draft.allowUntrustedSSL)
                }
            } header: {
                Text("Connection")
            } footer: {
                Text("Enter the IP address or domain name. Do not include http:// or https://")
            }

            // MARK: Credentials
            Section("Credentials") {
                TextField("Username", text: $draft.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .textContentType(.username)
                    .submitLabel(.next)

                SecureField("Password", text: $draft.password)
                    .textContentType(.password)
                    .submitLabel(.done)
            }

            // MARK: Polling
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Refresh Interval")
                        Spacer()
                        Text("\(Int(draft.pollingInterval))s")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $draft.pollingInterval, in: 2...60, step: 1)
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
                        if draft.isTestingConnection {
                            ProgressView()
                                .padding(.trailing, 4)
                        }
                        Text(draft.isTestingConnection ? "Testing…" : "Test Connection")
                    }
                }
                .accessibilityIdentifier("test_connection_button")
                .disabled(draft.host.isEmpty || draft.isTestingConnection)

                // Result feedback
                switch draft.connectionTestResult {
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
            if !draft.isNew {
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
                if draft.delete(in: modelContext) { dismiss() }
            }
        } message: {
            Text("Are you sure you want to delete this server profile?")
        }
        .navigationTitle(draft.isNew ? "Add Server" : "Edit Server")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!draft.canSave)
                    .accessibilityIdentifier("save_server_button")
            }
        }
        .onDisappear { testTask?.cancel() }
        .alert("Could Not Save Server", isPresented: Binding(
            get: { draft.error != nil },
            set: { if !$0 { draft.error = nil } }
        )) {
            Button("OK") { draft.error = nil }
        } message: {
            Text(draft.error ?? "Unknown error")
        }
        .presentationSizing(.form)
    }

    // MARK: - Helpers

    private func testConnection() {
        testTask?.cancel()
        testTask = Task { await draft.testConnection() }
    }

    private func save() {
        if draft.save(in: modelContext) { dismiss() }
    }
}
