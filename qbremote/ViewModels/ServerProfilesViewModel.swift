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

    var connectionTestResult: ConnectionTestResult = .idle
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
    
    @MainActor
    func verifyActiveConnection(for profile: ServerProfile) {
        activeConnectionTask?.cancel()
        
        activeConnectionTask = Task {
            activeConnectionStatus = .connecting
            let password = KeychainService.loadPassword(for: profile.id) ?? ""
            
            let scheme = profile.useHTTPS ? "https" : "http"
            var urlString = "\(scheme)://\(profile.host)"
            if let port = profile.port {
                urlString = "\(scheme)://\(profile.host):\(port)"
            }
            
            guard let url = URL(string: urlString) else {
                activeConnectionStatus = .error("Invalid URL format.")
                return
            }
            
            let service: QBittorrentAPIServiceProtocol
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-isUITest") || UserDefaults.standard.bool(forKey: "isDemoMode") {
                service = MockQBittorrentAPIService()
            } else {
                service = QBittorrentAPIService(baseURL: url, allowUntrustedSSL: profile.allowUntrustedSSL)
            }
            #else
            service = QBittorrentAPIService(baseURL: url, allowUntrustedSSL: profile.allowUntrustedSSL)
            #endif
            
            do {
                let sid = try await service.login(username: profile.username, password: password)
                if !sid.isEmpty { try? await service.logout() }
                if !Task.isCancelled {
                    activeConnectionStatus = .connected
                }
            } catch let err as QBError {
                if !Task.isCancelled {
                    activeConnectionStatus = .error(err.errorDescription ?? "Unknown error")
                }
            } catch {
                if !Task.isCancelled {
                    activeConnectionStatus = .error(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Save / Delete

    func save(profile: ServerProfile, password: String) {
        // Save the new password
        KeychainService.savePassword(password, for: profile.id)
        
        // Update lastUpdated to trigger a reconnect in RootView
        profile.lastUpdated = Date.now
        
        try? modelContext?.save()
    }

    func delete(profile: ServerProfile) {
        KeychainService.deleteCredentials(for: profile.id)
        modelContext?.delete(profile)
        try? modelContext?.save()
    }

    func insertNew(_ profile: ServerProfile, password: String) {
        modelContext?.insert(profile)
        KeychainService.savePassword(password, for: profile.id)
        try? modelContext?.save()
    }

    // MARK: - Test Connection

    func testConnection(host: String, port: Int?, useHTTPS: Bool, allowUntrustedSSL: Bool, username: String, password: String, injectedService: QBittorrentAPIServiceProtocol? = nil) async {
        connectionTestResult = .testing
        
        let scheme = useHTTPS ? "https" : "http"
        var urlString = "\(scheme)://\(host)"
        if let port {
            urlString = "\(scheme)://\(host):\(port)"
        }
        
        guard let url = URL(string: urlString) else {
            connectionTestResult = .failure("Invalid URL format.")
            return
        }
        
        var service: QBittorrentAPIServiceProtocol
        if let injectedService {
            service = injectedService
        } else {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-isUITest") {
                service = MockQBittorrentAPIService()
            } else {
                service = QBittorrentAPIService(baseURL: url, allowUntrustedSSL: allowUntrustedSSL)
            }
            #else
            service = QBittorrentAPIService(baseURL: url, allowUntrustedSSL: allowUntrustedSSL)
            #endif
        }

        do {
            let sid = try await service.login(username: username, password: password)
            if !sid.isEmpty { try? await service.logout() }
            connectionTestResult = .success("Connected successfully!")
        } catch let err as QBError {
            connectionTestResult = .failure(err.errorDescription ?? "Unknown error")
        } catch {
            connectionTestResult = .failure(error.localizedDescription)
        }
    }

    func resetTestResult() {
        connectionTestResult = .idle
    }
}
