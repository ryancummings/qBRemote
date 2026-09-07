//
//  ExternalAddTorrentFlowView.swift
//  qbremote
//

import SwiftUI

struct ExternalAddTorrentFlowView: View {
    let url: URL
    let profiles: [ServerProfile]
    let onDismiss: () -> Void

    @State private var selectedProfile: ServerProfile?

    var body: some View {
        if profiles.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "server.rack")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No servers configured")
                    .font(.headline)
                Text("Add a server in the app first before opening external files.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Close") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        } else if profiles.count == 1 || selectedProfile != nil {
            let profile = selectedProfile ?? profiles.first!
            AuthWrapperAddTorrentView(url: url, profile: profile, onDismiss: onDismiss)
        } else {
            List(profiles) { profile in
                Button {
                    selectedProfile = profile
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(profile.name.isEmpty ? profile.host : profile.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(profile.host)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Select Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
            }
        }
    }
}

fileprivate struct AuthWrapperAddTorrentView: View {
    let url: URL
    let profile: ServerProfile
    let onDismiss: () -> Void

    @State private var viewModel = ExternalAddTorrentViewModel()

    var body: some View {
        Group {
            if let session = viewModel.session {
                AddTorrentView(session: session, initialURL: url, onSuccess: onDismiss)
            } else if let error = viewModel.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)
                    Text("Authentication Failed")
                        .font(.headline)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Close") {
                        onDismiss()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Authenticating…")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .task {
                    await viewModel.prepare(profile: profile)
                }
            }
        }
    }

}
