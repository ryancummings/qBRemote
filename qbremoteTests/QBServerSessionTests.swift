import Foundation
import Testing
@testable import qbremote

@MainActor
struct QBServerSessionTests {
    @Test("A saved cookie runs a typed operation without password login")
    func savedCookie() async throws {
        let profile = ServerProfile(name: "Session", host: "localhost", username: "admin")
        let credentials = MemorySessionCredentials()
        credentials.cookies[profile.id] = "saved"
        let transport = SessionTransport { request in
            #expect(request.value(forHTTPHeaderField: "Cookie") == "SID=saved")
            #expect(request.url?.path == "/api/v2/torrents/info")
            return (200, "[]", [:])
        }
        let service = QBittorrentAPIService(baseURL: try #require(profile.baseURL), transport: transport)
        let session = try QBServerSession(profile: profile, service: service, credentials: credentials)

        #expect(try await session.run(.torrents(filter: .all)).isEmpty)
        #expect(session.connectionStatus == .connected)
        #expect(transport.requests.count == 1)
    }

    @Test("An explicit rejection replaces only this profile's cookie", arguments: [401, 403])
    func rejectedCookie(status: Int) async throws {
        let profile = ServerProfile(host: "localhost")
        let other = UUID()
        let credentials = MemorySessionCredentials()
        credentials.cookies = [profile.id: "expired", other: "other-cookie"]
        credentials.passwords[profile.id] = "secret"
        var logins = 0
        var reads = 0
        let transport = SessionTransport { request in
            if request.url?.path == "/api/v2/auth/login" {
                logins += 1
                #expect(credentials.cookies[profile.id] == nil)
                return (200, "Ok.", ["Set-Cookie": "SID=fresh; Path=/"])
            }
            reads += 1
            return request.value(forHTTPHeaderField: "Cookie") == "SID=fresh"
                ? (200, "[]", [:]) : (status, "", [:])
        }
        let session = try makeSession(profile, credentials, transport)
        #expect(try await session.run(.torrents()).isEmpty)
        #expect(logins == 1)
        #expect(reads == 2)
        #expect(credentials.cookies[profile.id] == "fresh")
        #expect(credentials.cookies[other] == "other-cookie")
        #expect(credentials.passwords[profile.id] == "secret")
        #expect(session.connectionStatus == .connected)
    }

    @Test("A second rejection stops after one retry", arguments: [401, 403])
    func secondRejection(status: Int) async throws {
        let profile = ServerProfile(host: "localhost")
        let credentials = MemorySessionCredentials()
        credentials.passwords[profile.id] = "secret"
        var logins = 0
        var reads = 0
        let transport = SessionTransport { request in
            if request.url?.path == "/api/v2/auth/login" {
                logins += 1
                return (200, "Ok.", ["Set-Cookie": "SID=rejected; Path=/"])
            }
            reads += 1
            return (status, "", [:])
        }
        let session = try makeSession(profile, credentials, transport)
        await #expect(throws: QBError.self) { try await session.run(.torrents()) }
        #expect(logins == 1)
        #expect(reads == 2)
        #expect(credentials.cookies[profile.id] == nil)
        #expect(isFailed(session))
    }

    @Test("Missing or rejected passwords leave the invalid cookie deleted", arguments: [false, true])
    func failedLogin(hasPassword: Bool) async throws {
        let profile = ServerProfile(host: "localhost")
        let credentials = MemorySessionCredentials()
        credentials.cookies[profile.id] = "expired"
        credentials.passwords[profile.id] = hasPassword ? "wrong" : nil
        let transport = SessionTransport { request in
            request.url?.path == "/api/v2/auth/login" ? (200, "Fails.", [:]) : (403, "", [:])
        }
        let session = try makeSession(profile, credentials, transport)
        await #expect(throws: QBError.self) { try await session.run(.torrents()) }
        #expect(credentials.cookies[profile.id] == nil)
        #expect(isFailed(session))
        #expect(transport.requests.count == (hasPassword ? 2 : 1))
        let reason = hasPassword ? "Fails." : "No password stored. Please re-enter credentials."
        #expect(session.connectionStatus == .error(QBError.loginFailed(reason).localizedDescription))
    }

    @Test("Login without SID remains valid across operations")
    func emptySID() async throws {
        let profile = ServerProfile(host: "localhost")
        let credentials = MemorySessionCredentials()
        credentials.cookies[profile.id] = "expired"
        credentials.passwords[profile.id] = "secret"
        var loggedIn = false
        let transport = SessionTransport { request in
            if request.url?.path == "/api/v2/auth/login" {
                loggedIn = true
                return (200, "Ok.", [:])
            }
            if loggedIn { #expect(request.value(forHTTPHeaderField: "Cookie") == nil) }
            return loggedIn ? (200, "[]", [:]) : (401, "", [:])
        }
        let session = try makeSession(profile, credentials, transport)
        _ = try await session.run(.torrents())
        _ = try await session.run(.torrents())
        #expect(transport.requests.filter { $0.url?.path == "/api/v2/auth/login" }.count == 1)
        #expect(credentials.cookies[profile.id] == nil)
        #expect(session.connectionStatus == .connected)
    }

    @Test("Decoding and operation errors preserve connected status", arguments: [200, 404, 500])
    func operationFailure(status: Int) async throws {
        let profile = ServerProfile(host: "localhost")
        let transport = SessionTransport { _ in (200, "[]", [:]) }
        let session = try makeSession(profile, MemorySessionCredentials(), transport)
        _ = try await session.run(.torrents())
        transport.handler = { _ in (status, "invalid JSON", [:]) }
        await #expect(throws: QBError.self) { try await session.run(.torrents()) }
        #expect(session.connectionStatus == .connected)
        #expect(transport.requests.count == 2)
    }

    @Test("Transport errors fail the connection without attempting login")
    func transportFailure() async throws {
        let profile = ServerProfile(host: "localhost")
        let transport = SessionTransport { _ in (200, "[]", [:]) }
        let session = try makeSession(profile, MemorySessionCredentials(), transport)
        _ = try await session.run(.torrents())
        transport.handler = { _ in throw URLError(.timedOut) }
        await #expect(throws: QBError.self) { try await session.run(.torrents()) }
        #expect(isFailed(session))
        #expect(transport.requests.count == 2)
    }

    @Test("Concurrent rejections share login, including delayed old-cookie responses", arguments: [false, true])
    func concurrentFailures(delayed: Bool) async throws {
        let profile = ServerProfile(host: "localhost")
        let credentials = MemorySessionCredentials()
        credentials.cookies[profile.id] = "expired"
        credentials.passwords[profile.id] = "secret"
        let bothRequested = SessionGate()
        let loggedIn = SessionGate()
        var oldRequests = 0
        var logins = 0
        let transport = SessionTransport { request in
            if request.url?.path == "/api/v2/auth/login" {
                logins += 1
                await Task.yield()
                loggedIn.open()
                return (200, "Ok.", ["Set-Cookie": "SID=fresh; Path=/"])
            }
            if request.value(forHTTPHeaderField: "Cookie") == "SID=expired" {
                oldRequests += 1
                let second = oldRequests == 2
                if second { bothRequested.open() }
                await bothRequested.wait()
                if second && delayed { await loggedIn.wait() }
                return (403, "", [:])
            }
            if request.url?.path == "/api/v2/transfer/info" {
                return (200, Self.statsJSON, [:])
            }
            return (200, "[]", [:])
        }
        let session = try makeSession(profile, credentials, transport)
        async let torrents = session.run(.torrents())
        async let stats = session.run(.globalStats)
        let result = try await (torrents, stats)
        #expect(result.0.isEmpty)
        #expect(result.1.downloadSpeed == 12)
        #expect(logins == 1)
        #expect(oldRequests == 2)
        #expect(credentials.cookies[profile.id] == "fresh")
        #expect(session.connectionStatus == .connected)
    }

    @Test("Cancellation preserves connection status and does not log in")
    func cancellation() async throws {
        let profile = ServerProfile(host: "localhost")
        let transport = SessionTransport { _ in (200, "[]", [:]) }
        let session = try makeSession(profile, MemorySessionCredentials(), transport)
        _ = try await session.run(.torrents())
        transport.handler = { _ in throw URLError(.cancelled) }
        await #expect(throws: CancellationError.self) { try await session.run(.torrents()) }
        #expect(session.connectionStatus == .connected)
        #expect(transport.requests.count == 2)
    }

    @Test("The simulated adapter supports typed demo operations")
    func demo() async throws {
        let session = try QBServerSession(
            profile: ServerProfile(host: "demo.local"),
            service: MockQBittorrentAPIService(simulate: false),
            credentials: MemorySessionCredentials()
        )
        #expect(try await !session.run(.torrents()).isEmpty)
        _ = try await session.run(.globalStats)
        #expect(session.connectionStatus == .connected)
    }

    @Test("A retry decoding error preserves the successful login status")
    func retryDecodingFailure() async throws {
        let profile = ServerProfile(host: "localhost")
        let credentials = MemorySessionCredentials()
        credentials.passwords[profile.id] = "secret"
        var loggedIn = false
        let transport = SessionTransport { request in
            if request.url?.path == "/api/v2/auth/login" {
                loggedIn = true
                return (200, "Ok.", [:])
            }
            return loggedIn ? (200, "invalid JSON", [:]) : (401, "", [:])
        }
        let session = try makeSession(profile, credentials, transport)
        await #expect(throws: QBError.self) { try await session.run(.torrents()) }
        #expect(session.connectionStatus == .connected)
        #expect(transport.requests.count == 3)
    }

    @Test("Cancelling one operation does not cancel another operation's shared login")
    func sharedLoginCancellation() async throws {
        let profile = ServerProfile(host: "localhost")
        let credentials = MemorySessionCredentials()
        credentials.passwords[profile.id] = "secret"
        let loginStarted = SessionGate()
        let finishLogin = SessionGate()
        var logins = 0
        var loggedIn = false
        let transport = SessionTransport { request in
            if request.url?.path == "/api/v2/auth/login" {
                logins += 1
                loginStarted.open()
                await finishLogin.wait()
                loggedIn = true
                return (200, "Ok.", [:])
            }
            return loggedIn ? (200, "[]", [:]) : (401, "", [:])
        }
        let session = try makeSession(profile, credentials, transport)
        let cancelled = Task { try await session.run(.torrents()) }
        await loginStarted.wait()
        let remaining = Task { try await session.run(.torrents()) }
        cancelled.cancel()
        finishLogin.open()
        await #expect(throws: CancellationError.self) { try await cancelled.value }
        #expect(try await remaining.value.isEmpty)
        #expect(logins == 1)
        #expect(session.connectionStatus == .connected)
    }

    @Test("A later operation can recover after failed login")
    func recoverAfterFailedLogin() async throws {
        let profile = ServerProfile(host: "localhost")
        let credentials = MemorySessionCredentials()
        let transport = SessionTransport { request in
            if request.url?.path == "/api/v2/auth/login" {
                return (200, "Ok.", ["Set-Cookie": "SID=fresh; Path=/"])
            }
            return request.value(forHTTPHeaderField: "Cookie") == "SID=fresh"
                ? (200, "[]", [:]) : (403, "", [:])
        }
        let session = try makeSession(profile, credentials, transport)
        await #expect(throws: QBError.self) { try await session.run(.torrents()) }
        credentials.passwords[profile.id] = "corrected"
        #expect(try await session.run(.torrents()).isEmpty)
        #expect(session.connectionStatus == .connected)
    }

    private static let statsJSON = "{\"dl_info_speed\":12,\"up_info_speed\":3,\"dl_info_data\":100,\"up_info_data\":20}"

    private func makeSession(
        _ profile: ServerProfile, _ credentials: MemorySessionCredentials, _ transport: SessionTransport
    ) throws -> QBServerSession {
        try QBServerSession(
            profile: profile,
            service: QBittorrentAPIService(baseURL: #require(profile.baseURL), transport: transport),
            credentials: credentials
        )
    }

    private func isFailed(_ session: QBServerSession) -> Bool {
        if case .error = session.connectionStatus { return true }
        return false
    }

}

extension QBServerSessionTests {
    @Test("Tag transport failures fail the connection without login")
    func tagTransportFailure() async throws {
        let profile = ServerProfile(host: "localhost")
        let transport = SessionTransport { _ in (200, "[]", [:]) }
        let session = try makeSession(profile, MemorySessionCredentials(), transport)
        _ = try await session.run(.torrentTags)
        transport.handler = { _ in throw URLError(.timedOut) }
        await #expect(throws: QBError.self) { try await session.run(.torrentTags) }
        #expect(isFailed(session))
        // A second failed read must not turn the failed session healthy.
        await #expect(throws: QBError.self) { try await session.run(.torrentTags) }
        #expect(isFailed(session))
        #expect(transport.requests.count == 3)
    }

    @Test("Tag cancellation propagates without changing connection status", arguments: [false, true])
    func tagCancellation(failed: Bool) async throws {
        let profile = ServerProfile(host: "localhost")
        let transport = SessionTransport { _ in (200, "[]", [:]) }
        let session = try makeSession(profile, MemorySessionCredentials(), transport)
        _ = try await session.run(.torrentTags)
        if failed {
            transport.handler = { _ in throw URLError(.timedOut) }
            await #expect(throws: QBError.self) { try await session.run(.torrents()) }
        }
        let previousStatus = session.connectionStatus
        transport.handler = { _ in throw URLError(.cancelled) }
        await #expect(throws: CancellationError.self) { try await session.run(.torrentTags) }
        #expect(session.connectionStatus == previousStatus)
        #expect(transport.requests.count == (failed ? 3 : 2))
    }

    @Test("Unsupported or malformed tag responses retain the empty fallback", arguments: [200, 404, 500])
    func tagOperationFallback(status: Int) async throws {
        let profile = ServerProfile(host: "localhost")
        let transport = SessionTransport { _ in (status, "invalid JSON", [:]) }
        let session = try makeSession(profile, MemorySessionCredentials(), transport)
        #expect(try await session.run(.torrentTags).isEmpty)
        #expect(session.connectionStatus == .connected)
        #expect(transport.requests.count == 1)
    }

}

@MainActor
final class MemorySessionCredentials: QBSessionCredentials {
    var cookies: [UUID: String] = [:]
    var passwords: [UUID: String] = [:]

    func loadCookie(for id: UUID) -> String? { cookies[id] }
    func loadPassword(for id: UUID) -> String? { passwords[id] }
    func saveCookie(_ cookie: String, for id: UUID) { cookies[id] = cookie }
    func deleteCookie(for id: UUID) { cookies[id] = nil }
}

@MainActor
final class SessionTransport: QBittorrentTransport {
    typealias Handler = (URLRequest) async throws -> (Int, String, [String: String])
    var requests: [URLRequest] = []
    var handler: Handler

    init(handler: @escaping Handler) { self.handler = handler }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let (status, body, headers) = try await handler(request)
        let url = try #require(request.url)
        let response = try #require(HTTPURLResponse(
            url: url, statusCode: status, httpVersion: nil, headerFields: headers
        ))
        return (Data(body.utf8), response)
    }
}

@MainActor
final class SessionGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters = []
        for waiter in pending { waiter.resume() }
    }
}
