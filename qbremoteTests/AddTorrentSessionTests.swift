import Foundation
import Testing
@testable import qbremote

@MainActor
struct AddTorrentSessionTests {
    @Test("An active-profile URL or magnet addition restores its saved cookie and retries once", arguments: [
        "magnet:?xt=urn:btih:123", "https://example.com/test.torrent"
    ])
    func activeAddition(url: String) async throws {
        let profile = ServerProfile(host: "active.local", isActive: true)
        KeychainService.saveCookie("expired", for: profile.id)
        KeychainService.savePassword("password", for: profile.id)
        defer { KeychainService.deleteCredentials(for: profile.id) }
        let transport = SessionTransport { request in
            if request.url?.path == "/api/v2/auth/login" {
                return (200, "Ok.", ["Set-Cookie": "SID=fresh; Path=/"])
            }
            return request.value(forHTTPHeaderField: "Cookie") == "SID=fresh"
                ? (200, "Ok.", [:]) : (403, "", [:])
        }
        let list = TorrentListViewModel()
        list.configure(with: profile, injectedService: QBittorrentAPIService(
            baseURL: try #require(profile.baseURL), transport: transport
        ))
        let model = AddTorrentViewModel()
        model.configure(session: try #require(list.sessionForAdding()))
        model.magnetURL = " \(url) "
        model.savePath = "/downloads/new folder"
        await model.submit()
        if case .success = model.submissionState {} else { Issue.record("Expected successful addition") }
        let additions = transport.requests.filter { $0.url?.path == "/api/v2/torrents/add" }
        #expect(additions.count == 2)
        #expect(additions.first?.value(forHTTPHeaderField: "Cookie") == "SID=expired")
        #expect(additions.last?.httpBody == additions.first?.httpBody)
        #expect(transport.requests.filter { $0.url?.path == "/api/v2/auth/login" }.count == 1)
        #expect(KeychainService.loadCookie(for: profile.id) == "fresh")
        #expect(list.activeProfileId == profile.id)
    }

    @Test("An external file addition uses an inactive profile and recovers when authentication expires")
    func inactiveFileAddition() async throws {
        let active = ServerProfile(host: "active.local", isActive: true)
        let destination = ServerProfile(host: "inactive.local")
        let credentials = MemorySessionCredentials()
        credentials.cookies[destination.id] = "saved"
        credentials.passwords[destination.id] = "password"
        let transport = SessionTransport { request in
            if request.url?.path == "/api/v2/transfer/info" {
                return (200, "{\"dl_info_speed\":0,\"up_info_speed\":0,\"dl_info_data\":0,\"up_info_data\":0}", [:])
            }
            if request.url?.path == "/api/v2/auth/login" {
                return (200, "Ok.", ["Set-Cookie": "SID=fresh; Path=/"])
            }
            return request.value(forHTTPHeaderField: "Cookie") == "SID=fresh"
                ? (200, "Ok.", [:]) : (401, "", [:])
        }
        let external = ExternalAddTorrentViewModel()
        await external.prepare(profile: destination, injectedService: QBittorrentAPIService(
            baseURL: try #require(destination.baseURL), transport: transport
        ), credentials: credentials)
        #expect(external.error == nil)
        #expect(transport.requests.count == 1)
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Cookie") == "SID=saved")
        let model = AddTorrentViewModel()
        model.configure(session: try #require(external.session))
        model.mode = .file
        model.selectedFileData = Data([0, 255, 13, 10, 42])
        model.selectedFilename = "incoming.torrent"
        model.savePath = "/incoming files"
        await model.submit()
        if case .success = model.submissionState {} else { Issue.record("Expected successful file addition") }
        let additions = transport.requests.filter { $0.url?.path == "/api/v2/torrents/add" }
        #expect(additions.count == 2)
        for request in additions {
            #expect(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data; boundary=") == true)
            let body = try #require(request.httpBody)
            #expect(body.range(of: Data([0, 255, 13, 10, 42])) != nil)
            #expect(body.range(of: Data("filename=\"incoming.torrent\"".utf8)) != nil)
            #expect(body.range(of: Data("/incoming files".utf8)) != nil)
        }
        #expect(transport.requests.allSatisfy { $0.url?.host == "inactive.local" })
        #expect(credentials.cookies[destination.id] == "fresh")
        #expect(active.isActive)
        #expect(!destination.isActive)
    }

    @Test("Save path suggestions keep available sources when one endpoint fails")
    func suggestions() async throws {
        let profile = ServerProfile(host: "localhost")
        let transport = SessionTransport { request in
            switch request.url?.path {
            case "/api/v2/app/defaultSavePath": return (200, "/Downloads", [:])
            case "/api/v2/torrents/categories":
                return (200, "{\"media\":{\"name\":\"media\",\"savePath\":\"/archive\"},\"same\":{\"name\":\"same\",\"savePath\":\"/Downloads\"}}", [:])
            default: return (500, "", [:])
            }
        }
        let session = try QBServerSession(profile: profile, service: QBittorrentAPIService(
            baseURL: try #require(profile.baseURL), transport: transport
        ), credentials: MemorySessionCredentials())
        let model = AddTorrentViewModel()
        model.configure(session: session)
        await model.loadSavePathSuggestions()
        #expect(model.savePathSuggestions == ["/archive", "/Downloads"])
    }

    @Test("A second rejected addition stops retrying and presents an error")
    func rejectedAddition() async throws {
        let profile = ServerProfile(host: "localhost")
        let credentials = MemorySessionCredentials()
        credentials.cookies[profile.id] = "expired"
        credentials.passwords[profile.id] = "password"
        let transport = SessionTransport { request in
            request.url?.path == "/api/v2/auth/login"
                ? (200, "Ok.", ["Set-Cookie": "SID=fresh; Path=/"]) : (403, "", [:])
        }
        let session = try QBServerSession(profile: profile, service: QBittorrentAPIService(
            baseURL: try #require(profile.baseURL), transport: transport
        ), credentials: credentials)
        let model = AddTorrentViewModel()
        model.configure(session: session)
        model.magnetURL = "magnet:?xt=urn:btih:123"
        await model.submit()
        if case .failure(let message) = model.submissionState {
            #expect(message == QBError.forbidden.errorDescription)
        } else {
            Issue.record("Expected rejected addition")
        }
        #expect(transport.requests.filter { $0.url?.path == "/api/v2/torrents/add" }.count == 2)
        #expect(transport.requests.filter { $0.url?.path == "/api/v2/auth/login" }.count == 1)
        #expect(credentials.cookies[profile.id] == nil)
    }

}
