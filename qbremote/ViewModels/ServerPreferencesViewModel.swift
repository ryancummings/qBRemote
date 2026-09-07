//
//  ServerPreferencesViewModel.swift
//  qbremote
//

import Foundation
import SwiftData
import OSLog

@MainActor
@Observable
final class ServerPreferencesViewModel {
    private let logger = Logger(subsystem: "com.ryancummings.qbremote", category: "ServerPreferencesViewModel")
    
    var preferences: ServerPreferences?
    var originalPreferences: ServerPreferences?
    var isLoading = false
    var isSaving = false
    
    var error: Error?
    var showError = false
    var errorMessage = ""
    
    var profile: ServerProfile?
    private var session: QBServerSession?
    var connectionStatus: ConnectionStatus { session?.connectionStatus ?? .connecting }
    var modelContext: ModelContext?
    
    // UI Bindings
    var listenPortString: String = ""
    var webUIPortString: String = ""
    
    var upLimitKBString: String = ""
    var dlLimitKBString: String = ""
    var altUpLimitKBString: String = ""
    var altDlLimitKBString: String = ""
    
    func configure(with profile: ServerProfile, context: ModelContext, injectedService: QBittorrentAPIServiceProtocol? = nil) {
        self.profile = profile
        self.modelContext = context
        
        var serviceToUse = injectedService
        if serviceToUse == nil,
           ProcessInfo.processInfo.arguments.contains("-isUITest") || UserDefaults.standard.bool(forKey: "isDemoMode") {
            serviceToUse = MockQBittorrentAPIService(simulate: false)
        }
        do {
            self.session = try QBServerSession(profile: profile, service: serviceToUse)
        } catch {
            self.session = nil
            self.error = error
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }

    func loadPreferences() async {
        guard let session else { return }
        isLoading = true
        
        do {
            let prefs = try await session.run(.preferences)
            self.preferences = prefs
            self.originalPreferences = prefs
            
            // Populate UI strings
            self.listenPortString = prefs.listen_port.map(String.init) ?? ""
            self.webUIPortString = prefs.web_ui_port.map(String.init) ?? ""
            
            // Convert bytes/s to KB/s for UI
            self.upLimitKBString = prefs.up_limit.map { String($0 / 1024) } ?? ""
            self.dlLimitKBString = prefs.dl_limit.map { String($0 / 1024) } ?? ""
            self.altUpLimitKBString = prefs.alt_up_limit.map { String($0 / 1024) } ?? ""
            self.altDlLimitKBString = prefs.alt_dl_limit.map { String($0 / 1024) } ?? ""
            
        } catch {
            logger.error("Failed to load preferences: \(error.localizedDescription)")
            self.error = error
            self.errorMessage = (error as? QBError)?.errorDescription ?? error.localizedDescription
            self.showError = true
        }
        
        isLoading = false
    }
    
    func savePreferences() async -> Bool {
        guard let session, let profile, var prefs = preferences else { return false }
        isSaving = true
        
        // Update prefs from UI strings
        prefs.listen_port = Int(listenPortString)
        let oldWebUIPort = originalPreferences?.web_ui_port
        prefs.web_ui_port = Int(webUIPortString)
        
        let oldUseHTTPS = originalPreferences?.use_https
        
        prefs.up_limit = Int(upLimitKBString).map { $0 * 1024 }
        prefs.dl_limit = Int(dlLimitKBString).map { $0 * 1024 }
        prefs.alt_up_limit = Int(altUpLimitKBString).map { $0 * 1024 }
        prefs.alt_dl_limit = Int(altDlLimitKBString).map { $0 * 1024 }
        
        do {
            try await session.run(.setPreferences(prefs))
            
            // Update local profile if connection settings changed
            var needsReconnect = false
            if prefs.web_ui_port != oldWebUIPort || prefs.use_https != oldUseHTTPS {
                profile.port = prefs.web_ui_port
                if let useHttps = prefs.use_https {
                    profile.useHTTPS = useHttps
                }
                needsReconnect = true
            }
            
            if needsReconnect {
                profile.lastUpdated = Date.now
                try? modelContext?.save()
            }
            
            isSaving = false
            return true
            
        } catch {
            logger.error("Failed to save preferences: \(error.localizedDescription)")
            self.error = error
            self.errorMessage = (error as? QBError)?.errorDescription ?? error.localizedDescription
            self.showError = true
            isSaving = false
            return false
        }
    }
    
    var hasConnectionSettingsChanged: Bool {
        guard let original = originalPreferences, let current = preferences else { return false }
        let currentWebUI = Int(webUIPortString)
        let oldWebUIPort = original.web_ui_port
        let oldUseHTTPS = original.use_https
        
        return currentWebUI != oldWebUIPort || current.use_https != oldUseHTTPS
    }
}
