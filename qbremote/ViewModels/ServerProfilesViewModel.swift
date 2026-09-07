//
//  ServerProfilesViewModel.swift
//  qbremote
//

import Foundation
import SwiftData

// MARK: - Connection Test Result

enum ConnectionTestResult {
    case idle
    case testing
    case success(String)    // success message
    case failure(String)    // error message

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

// MARK: - ViewModel

@Observable
final class ServerProfilesViewModel {

    enum ActiveConnectionStatus: Equatable {
        case idle
        case connecting
        case connected
        case error(String)
    }

    var activeConnectionStatus: ActiveConnectionStatus = .idle
    private var modelContext: ModelContext?
    private var activeConnectionTask: Task<Void, Never>?

    // MARK: - Init / Context

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Active Profile

    func activeProfile(from profiles: [ServerProfile]) -> ServerProfile? {
        profiles.first(where: { $0.isActive }) ?? profiles.first
    }

    func setActive(_ profile: ServerProfile, in profiles: [ServerProfile]) {
        for p in profiles { p.isActive = false }
        profile.isActive = true
        try? modelContext?.save()
        verifyActiveConnection(for: profile)
    }
    
    isolated deinit {
        activeConnectionTask?.cancel()
    }

    @MainActor
    func verifyActiveConnection(for profile: ServerProfile) {
        activeConnectionTask?.cancel()
        activeConnectionStatus = .connecting
        activeConnectionTask = Task { [weak self] in
            do {
                let session = try QBServerSessionFactory().session(for: profile)
                _ = try await session.run(.globalStats)
                if !Task.isCancelled { self?.activeConnectionStatus = .connected }
            } catch {
                if !Task.isCancelled { self?.activeConnectionStatus = .error(error.localizedDescription) }
            }
        }
    }
}
