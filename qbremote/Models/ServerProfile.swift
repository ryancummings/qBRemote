//
//  ServerProfile.swift
//  qbremote
//

import Foundation
import SwiftData

@Model
final class ServerProfile {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var host: String = ""
    var port: Int? = 8080
    var username: String = "admin"
    var useHTTPS: Bool = false
    var pollingInterval: Double = 5.0  // seconds
    var isActive: Bool = false
    var createdAt: Date = Date.now
    var lastUpdated: Date = Date.now
    var allowUntrustedSSL: Bool = false

    init(
        id: UUID = UUID(),
        name: String = "",
        host: String = "",
        port: Int? = 8080,
        username: String = "admin",
        useHTTPS: Bool = false,
        pollingInterval: Double = 5.0,
        isActive: Bool = false,
        createdAt: Date = .now,
        lastUpdated: Date = .now,
        allowUntrustedSSL: Bool = false
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.useHTTPS = useHTTPS
        self.pollingInterval = pollingInterval
        self.isActive = isActive
        self.createdAt = createdAt
        self.lastUpdated = lastUpdated
        self.allowUntrustedSSL = allowUntrustedSSL
    }

    var baseURL: URL? {
        let scheme = useHTTPS ? "https" : "http"
        if let port {
            return URL(string: "\(scheme)://\(host):\(port)")
        } else {
            return URL(string: "\(scheme)://\(host)")
        }
    }
}
