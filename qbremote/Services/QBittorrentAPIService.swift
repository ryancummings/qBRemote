//
//  QBittorrentAPIService.swift
//  qbremote
//

import Foundation

// MARK: - Errors

enum QBError: LocalizedError {
    case invalidURL
    case unauthorized
    case forbidden
    case loginFailed(String)
    case requestFailed(Int)
    case decodingFailed(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:               return "Invalid server URL. Check the host and port."
        case .unauthorized:             return "Unauthorized (401). Check credentials or reverse proxy headers."
        case .forbidden:                return "Forbidden (403). Session expired, IP banned, or invalid subnet."
        case .loginFailed(let msg):     return "Login failed: \(msg)"
        case .requestFailed(let code):  return "Request failed with HTTP \(code)."
        case .decodingFailed(let msg):  return "Failed to parse server response: \(msg)"
        case .networkError(let err):
            if let urlErr = err as? URLError {
                switch urlErr.code {
                case .timedOut:             return "Connection timed out. Is the server reachable?"
                case .cannotConnectToHost:  return "Cannot connect to host. Check IP address and port."
                case .networkConnectionLost: return "Network connection lost."
                case .notConnectedToInternet: return "No internet / network connection."
                case .serverCertificateHasBadDate, .serverCertificateUntrusted, .serverCertificateHasUnknownRoot, .secureConnectionFailed:
                    return "SSL Certificate Error. If using a self-signed certificate, enable 'Allow Untrusted SSL' in server settings."
                default: break
                }
            }
            return "Network error: \(err.localizedDescription)"
        }
    }
}

// MARK: - API Service

@MainActor
final class QBittorrentAPIService: QBittorrentAPIServiceProtocol {

    // MARK: - State

    private(set) var baseURL: URL
    private var sessionCookie: String?

    private let transport: any QBittorrentTransport

    // MARK: - Init

    init(
        baseURL: URL,
        allowUntrustedSSL: Bool = false,
        transport: (any QBittorrentTransport)? = nil
    ) {
        self.baseURL = baseURL
        self.transport = transport ?? URLSessionQBittorrentTransport(
            allowUntrustedSSL: allowUntrustedSSL
        )
    }

    // MARK: - Session Cookie Management

    func setSessionCookie(_ cookie: String?) {
        self.sessionCookie = cookie
    }

    // MARK: - Auth

    /// Log in and return the SID cookie value (without the "SID=" prefix).
    func login(username: String, password: String) async throws -> String {
        let url = baseURL.appending(path: "/api/v2/auth/login")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(baseURL.absoluteString, forHTTPHeaderField: "Referer")
        request.httpBody = "username=\(username.urlEncoded)&password=\(password.urlEncoded)"
            .data(using: .utf8)

        let (data, response) = try await performRequest(request, authenticated: false)

        guard let http = response as? HTTPURLResponse else { throw QBError.loginFailed("No HTTP response") }
        if http.statusCode == 403 { throw QBError.loginFailed("IP banned due to failed login attempts") }
        guard http.statusCode == 200 else { throw QBError.requestFailed(http.statusCode) }

        // Look for the SID cookie in Set-Cookie header
        if let raw = http.value(forHTTPHeaderField: "Set-Cookie"),
           let sid = extractSID(from: raw) {
            self.sessionCookie = sid
            return sid
        }

        // Fallback: body might be "Ok." or "Fails."
        let body = String(data: data, encoding: .utf8) ?? ""
        if body.lowercased().contains("ok") {
            // Some older builds don't set SID on default auth – treat as success, no cookie
            return ""
        }
        throw QBError.loginFailed(body)
    }

    func logout() async throws {
        try await postEmpty(path: "/api/v2/auth/logout")
        sessionCookie = nil
    }

    // MARK: - Torrents

    nonisolated struct TorrentCategory: Decodable {
        let name: String
        let savePath: String

        enum CodingKeys: String, CodingKey {
            case name
            case savePath = "save_path"
        }
    }

    func getTorrents(filter: TorrentFilter = .all) async throws -> [Torrent] {
        var components = URLComponents(url: baseURL.appending(path: "/api/v2/torrents/info"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "filter", value: filter.apiValue)]
        let request = try authenticatedGET(url: components.url!)
        let (data, _) = try await performRequest(request)
        return try await decode([Torrent].self, from: data)
    }

    func getGlobalStats() async throws -> GlobalStats {
        let request = try authenticatedGET(url: baseURL.appending(path: "/api/v2/transfer/info"))
        let (data, _) = try await performRequest(request)
        return try await decode(GlobalStats.self, from: data)
    }

    func getDefaultSavePath() async throws -> String {
        let request = try authenticatedGET(url: baseURL.appending(path: "/api/v2/app/defaultSavePath"))
        let (data, _) = try await performRequest(request)
        return String(data: data, encoding: .utf8) ?? ""
    }

    func getTorrentCategories() async throws -> [String: TorrentCategory] {
        let request = try authenticatedGET(url: baseURL.appending(path: "/api/v2/torrents/categories"))
        let (data, _) = try await performRequest(request)
        do {
            return try await decode([String: TorrentCategory].self, from: data)
        } catch {
            // Some versions return an empty array if there are no categories instead of an empty dictionary.
            if let _ = try? await decode([TorrentCategory].self, from: data) {
                return [:]
            }
            throw error
        }
    }

    func getPreferences() async throws -> ServerPreferences {
        let request = try authenticatedGET(url: baseURL.appending(path: "/api/v2/app/preferences"))
        let (data, _) = try await performRequest(request)
        return try await decode(ServerPreferences.self, from: data)
    }

    func setPreferences(_ preferences: ServerPreferences) async throws {
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(preferences)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw QBError.decodingFailed("Failed to encode preferences to string")
        }
        let body = "json=\(jsonString.urlEncoded)"
        try await postForm(path: "/api/v2/app/setPreferences", body: body)
    }

    // MARK: - Add Torrents

    func addTorrentByURL(_ magnetOrURL: String, savePath: String) async throws {
        var body = "urls=\(magnetOrURL.urlEncoded)"
        if !savePath.isEmpty { body += "&savepath=\(savePath.urlEncoded)" }
        try await postForm(path: "/api/v2/torrents/add", body: body)
    }

    func addTorrentByData(_ data: Data, filename: String, savePath: String) async throws {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: baseURL.appending(path: "/api/v2/torrents/add"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(baseURL.absoluteString, forHTTPHeaderField: "Referer")
        if let sid = sessionCookie { request.setValue("SID=\(sid)", forHTTPHeaderField: "Cookie") }

        var body = Data()
        // torrent file part
        body.append("--\(boundary)\r\n".utf8Data)
        body.append("Content-Disposition: form-data; name=\"torrents\"; filename=\"\(filename)\"\r\n".utf8Data)
        body.append("Content-Type: application/x-bittorrent\r\n\r\n".utf8Data)
        body.append(data)
        body.append("\r\n".utf8Data)
        // save path part (if provided)
        if !savePath.isEmpty {
            body.append("--\(boundary)\r\n".utf8Data)
            body.append("Content-Disposition: form-data; name=\"savepath\"\r\n\r\n".utf8Data)
            body.append("\(savePath)\r\n".utf8Data)
        }
        body.append("--\(boundary)--\r\n".utf8Data)
        request.httpBody = body

        try await performRequestIgnoringBody(request)
    }

    // MARK: - Torrent Actions

    func pauseTorrents(hashes: [String]) async throws {
        let body = "hashes=\(hashes.joined(separator: "|"))"
        try await postForm(path: "/api/v2/torrents/stop", body: body)
    }

    func resumeTorrents(hashes: [String]) async throws {
        let body = "hashes=\(hashes.joined(separator: "|"))"
        try await postForm(path: "/api/v2/torrents/start", body: body)
    }

    func deleteTorrents(hashes: [String], deleteFiles: Bool) async throws {
        let body = "hashes=\(hashes.joined(separator: "|"))&deleteFiles=\(deleteFiles ? "true" : "false")"
        try await postForm(path: "/api/v2/torrents/delete", body: body)
    }

    func setTorrentLocation(hashes: [String], location: String) async throws {
        let body = "hashes=\(hashes.joined(separator: "|"))&location=\(location.urlEncoded)"
        try await postForm(path: "/api/v2/torrents/setLocation", body: body)
    }

    func setTorrentCategory(hashes: [String], category: String) async throws {
        let body = "hashes=\(hashes.joined(separator: "|"))&category=\(category.urlEncoded)"
        try await postForm(path: "/api/v2/torrents/setCategory", body: body)
    }

    func getTorrentTags() async throws -> [String] {
        do {
            let request = try authenticatedGET(url: baseURL.appending(path: "/api/v2/torrents/tags"))
            let (data, _) = try await performRequest(request)
            return try await decode([String].self, from: data)
        } catch let error as QBError {
            switch error {
            case .unauthorized, .forbidden: throw error
            default:                       return []
            }
        } catch {
            return []
        }
    }

    func addTorrentTags(hashes: [String], tags: [String]) async throws {
        let body = "hashes=\(hashes.joined(separator: "|"))&tags=\(tags.joined(separator: ",").urlEncoded)"
        try await postForm(path: "/api/v2/torrents/addTags", body: body)
    }

    func removeTorrentTags(hashes: [String], tags: [String]) async throws {
        let body = "hashes=\(hashes.joined(separator: "|"))&tags=\(tags.joined(separator: ",").urlEncoded)"
        try await postForm(path: "/api/v2/torrents/removeTags", body: body)
    }

    // MARK: - Private Helpers

    private func authenticatedGET(url: URL) throws -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(baseURL.absoluteString, forHTTPHeaderField: "Referer")
        if let sid = sessionCookie { req.setValue("SID=\(sid)", forHTTPHeaderField: "Cookie") }
        return req
    }

    private func postForm(path: String, body: String) async throws {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(baseURL.absoluteString, forHTTPHeaderField: "Referer")
        if let sid = sessionCookie { request.setValue("SID=\(sid)", forHTTPHeaderField: "Cookie") }
        request.httpBody = body.data(using: .utf8)
        try await performRequestIgnoringBody(request)
    }

    private func postEmpty(path: String) async throws {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue(baseURL.absoluteString, forHTTPHeaderField: "Referer")
        if let sid = sessionCookie { request.setValue("SID=\(sid)", forHTTPHeaderField: "Cookie") }
        try await performRequestIgnoringBody(request)
    }

    @discardableResult
    private func performRequest(_ request: URLRequest, authenticated: Bool = true) async throws -> (Data, URLResponse) {
        do {
            let (data, response) = try await transport.data(for: request)
            if authenticated, let http = response as? HTTPURLResponse {
                if http.statusCode == 401 {
                    throw QBError.unauthorized
                } else if http.statusCode == 403 {
                    throw QBError.forbidden
                } else if http.statusCode >= 400 {
                    throw QBError.requestFailed(http.statusCode)
                }
            }
            return (data, response)
        } catch let err as QBError {
            throw err
        } catch {
            throw QBError.networkError(error)
        }
    }

    private func performRequestIgnoringBody(_ request: URLRequest) async throws {
        let (_, response) = try await performRequest(request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 {
                throw QBError.unauthorized
            } else if http.statusCode == 403 {
                throw QBError.forbidden
            } else if http.statusCode >= 400 {
                throw QBError.requestFailed(http.statusCode)
            }
        }
    }

    nonisolated private func decode<T: Decodable & Sendable>(_ type: T.Type, from data: Data) async throws -> T {
        do {
            return try await Task.detached {
                try JSONDecoder().decode(type, from: data)
            }.value
        } catch {
            throw QBError.decodingFailed(error.localizedDescription)
        }
    }

    private func extractSID(from setCookie: String) -> String? {
        // Parse "SID=abcdefgh; Path=/"
        let parts = setCookie.components(separatedBy: ";")
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("SID=") {
                return String(trimmed.dropFirst(4))
            }
        }
        return nil
    }
}

// MARK: - String extensions

private extension String {
    var urlEncoded: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
    var utf8Data: Data { Data(utf8) }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) { append(data) }
    }
    var utf8Data: Data { self }
}
