//
//  Formatters.swift
//  qbremote
//

import Foundation

extension Int {
    /// Format bytes/s as human-readable speed string
    var speedString: String {
        ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .binary) + "/s"
    }

    /// Format bytes as human-readable size string
    var sizeString: String {
        ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .binary)
    }
}
