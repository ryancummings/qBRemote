//
//  QBittorrentTransport.swift
//  qbremote
//

import Foundation

@MainActor
protocol QBittorrentTransport: AnyObject, Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

@MainActor
final class URLSessionQBittorrentTransport: QBittorrentTransport {
    let configuration: URLSessionConfiguration

    private let session: URLSession

    init(allowUntrustedSSL: Bool) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.httpCookieAcceptPolicy = .never

        let delegate = allowUntrustedSSL ? SSLBypassDelegate() : nil
        self.configuration = configuration
        self.session = URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: nil
        )
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}
