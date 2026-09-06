//
//  ServerPreferences.swift
//  qbremote
//

import Foundation

nonisolated struct ServerPreferences: Codable, Equatable {
    // Connection
    var listen_port: Int?
    var upnp: Bool?
    
    // Global Speed Limits (bytes/s)
    var dl_limit: Int?
    var up_limit: Int?
    
    // Alternative Rate Limits
    var alt_dl_limit: Int?
    var alt_up_limit: Int?
    var scheduler_enabled: Bool?
    var schedule_from_hour: Int?
    var schedule_from_min: Int?
    var schedule_to_hour: Int?
    var schedule_to_min: Int?
    var schedule_days: Int? // 0 = Everyday, 1 = Weekday, 2 = Weekend, 3 = Monday, etc.
    
    // Web UI
    var web_ui_port: Int?
    var use_https: Bool?
    
    // BitTorrent
    var dht: Bool?
    var pex: Bool?
    var lpd: Bool?
    var encryption: Int? // 0 = Prefer, 1 = Force on, 2 = Force off
    
    // Downloads
    var save_path: String?
    var append_extension: Bool?
    var preallocate_all: Bool?
}
