import Foundation
import Testing
@testable import qbremote

@MainActor
struct TorrentOrganizationSessionTests {
    @Test("Organization mutations recover once and expose submission outcomes", arguments: [200, 403, 500])
    func submissions(retryStatus: Int) async throws {
        let profile = ServerProfile(host: "selected.local")
        let credentials = MemorySessionCredentials()
        credentials.passwords[profile.id] = "secret"
        var counts: [String: Int] = [:]
        let transport = SessionTransport { request in
            #expect(request.url?.host == "selected.local")
            let path = try #require(request.url?.path)
            counts[path, default: 0] += 1
            if path == "/api/v2/auth/login" { return (200, "Ok.", ["Set-Cookie": "SID=fresh; Path=/"]) }
            return (counts[path] == 1 ? 401 : retryStatus, "", [:])
        }
        let session = try QBServerSession(profile: profile, service: QBittorrentAPIService(
            baseURL: #require(profile.baseURL), transport: transport
        ), credentials: credentials)
        let move = MoveTorrentViewModel()
        move.configure(session: session, torrentHash: "hash", currentPath: "/old")
        move.savePath = "/new"
        await move.submit()
        if retryStatus == 200 {
            guard case .success = move.submissionState else { Issue.record("Move should succeed"); return }
        } else {
            guard case .failure(let message) = move.submissionState else { Issue.record("Move should fail"); return }
            #expect(!message.isEmpty)
        }
        let category = SetCategoryViewModel()
        category.configure(session: session, torrentHash: "hash", currentCategory: "old")
        category.category = ""
        await category.submit()
        if retryStatus == 200 {
            guard case .success = category.submissionState else { Issue.record("Category should succeed"); return }
        } else {
            guard case .failure = category.submissionState else { Issue.record("Category should fail"); return }
        }
        let tags = SetTagsViewModel()
        tags.configure(session: session, torrentHash: "hash", currentTagsString: "old, kept")
        tags.removeTag("old")
        tags.addTag(" new ")
        await tags.submit()
        if retryStatus == 200 {
            guard case .success = tags.submissionState else { Issue.record("Tags should succeed"); return }
            #expect(counts["/api/v2/torrents/removeTags"] == 2)
        } else {
            guard case .failure = tags.submissionState else { Issue.record("Tags should fail"); return }
            #expect(counts["/api/v2/torrents/removeTags"] == nil)
        }
        #expect(counts["/api/v2/torrents/setLocation"] == 2)
        #expect(counts["/api/v2/torrents/setCategory"] == 2)
        #expect(counts["/api/v2/torrents/addTags"] == 2)
        #expect(counts["/api/v2/auth/login"] == (retryStatus == 200 ? 4 : 3))
        let bodies = transport.requests.compactMap { $0.httpBody.flatMap { String(data: $0, encoding: .utf8) } }
        #expect(bodies.contains("hashes=hash&category="))
        #expect(bodies.contains("hashes=hash&tags=new"))
        if retryStatus == 200 { #expect(bodies.contains("hashes=hash&tags=old")) }
    }

    @Test("Tag suggestions recover from authentication rejection", arguments: [401, 403])
    func tagSuggestionRecovery(status: Int) async throws {
        let profile = ServerProfile(host: "localhost")
        let credentials = MemorySessionCredentials()
        credentials.passwords[profile.id] = "secret"
        var reads = 0
        let transport = SessionTransport { request in
            if request.url?.path == "/api/v2/auth/login" {
                return (200, "Ok.", ["Set-Cookie": "SID=fresh; Path=/"])
            }
            reads += 1
            return reads == 1 ? (status, "", [:]) : (200, "[\"restored\"]", [:])
        }
        let session = try QBServerSession(profile: profile, service: QBittorrentAPIService(
            baseURL: #require(profile.baseURL), transport: transport
        ), credentials: credentials)
        let tags = SetTagsViewModel()
        tags.configure(session: session, torrentHash: "hash", currentTagsString: "")
        await tags.loadTagSuggestions()
        #expect(tags.tagSuggestions == ["restored"])
        #expect(reads == 2)
        #expect(session.connectionStatus == .connected)
    }

    @Test("Organization suggestions retain sorting, deduplication, and empty-error fallback")
    func suggestions() async throws {
        let profile = ServerProfile(host: "localhost")
        let transport = SessionTransport { request in
            switch request.url?.path {
            case "/api/v2/app/defaultSavePath": return (200, "/Zulu", [:])
            case "/api/v2/torrents/categories":
                return (200, "{\"Beta\":{\"name\":\"Beta\",\"save_path\":\"/alpha\"},\"alpha\":{\"name\":\"alpha\",\"save_path\":\"/Zulu\"}}", [:])
            case "/api/v2/torrents/tags": return (200, "[\"Zulu\",\"alpha\"]", [:])
            default: return (200, "[]", [:])
            }
        }
        let session = try QBServerSession(profile: profile, service: QBittorrentAPIService(
            baseURL: #require(profile.baseURL), transport: transport
        ), credentials: MemorySessionCredentials())
        let move = MoveTorrentViewModel()
        move.configure(session: session, torrentHash: "hash", currentPath: "/old")
        await move.loadSavePathSuggestions()
        #expect(move.savePathSuggestions == ["/alpha", "/Zulu"])
        #expect(move.initialSavePath == "/old")
        move.savePath = "   "
        #expect(!move.canSubmit)
        let category = SetCategoryViewModel()
        category.configure(session: session, torrentHash: "hash", currentCategory: "old")
        await category.loadCategorySuggestions()
        #expect(category.categorySuggestions == ["alpha", "Beta"])
        let tags = SetTagsViewModel()
        tags.configure(session: session, torrentHash: "hash", currentTagsString: " old, old, kept, ")
        #expect(tags.currentTags == ["old", "kept"])
        await tags.loadTagSuggestions()
        #expect(tags.tagSuggestions == ["alpha", "Zulu"])
        transport.handler = { _ in (500, "", [:]) }
        await move.loadSavePathSuggestions()
        await category.loadCategorySuggestions()
        await tags.loadTagSuggestions()
        #expect(move.savePathSuggestions.isEmpty)
        #expect(category.categorySuggestions.isEmpty)
        #expect(tags.tagSuggestions.isEmpty)
    }
}
