import Foundation
import SwiftData
import Testing
@testable import qbremote

@MainActor
struct ServerProfileDraftTests {
    @Test("Testing draft values never touches saved profiles or credentials", arguments: [200, 403])
    func unsavedTest(status: Int) async throws {
        let context = try context()
        let profile = ServerProfile(name: "Original", host: "old.local", isActive: true)
        context.insert(profile)
        try context.save()
        let credentials = DraftTestCredentials()
        credentials.passwords[profile.id] = "original"
        let draft = ServerProfileDraft(profile: profile, credentials: credentials)
        draft.host = "new.local"
        draft.password = "unsaved"
        let readsBefore = credentials.reads
        let transport = SessionTransport { request in
            #expect(request.url?.host == "new.local")
            if request.url?.path == "/api/v2/auth/login" {
                #expect(request.httpBody.flatMap { String(data: $0, encoding: .utf8) } == "username=admin&password=unsaved")
                return (status, "Ok.", [:])
            }
            return (200, "", [:])
        }
        await draft.testConnection(using: QBServerSessionFactory { url, ssl in
            QBittorrentAPIService(baseURL: url, allowUntrustedSSL: ssl, transport: transport)
        })
        #expect(draft.connectionTestResult.isSuccess == (status == 200))
        #expect(credentials.reads == readsBefore)
        #expect(credentials.writes == 0)
        #expect(profile.host == "old.local")
        #expect(try context.fetchCount(FetchDescriptor<ServerProfile>()) == 1)
        #expect(!context.hasChanges)
    }

    @Test("Testing a new draft leaves it unsaved", arguments: [200, 403])
    func newDraftTest(status: Int) async throws {
        let credentials = DraftTestCredentials()
        let draft = ServerProfileDraft(profile: nil, credentials: credentials)
        draft.host = "unsaved.local"
        let transport = SessionTransport { _ in (status, "Ok.", [:]) }
        await draft.testConnection(using: QBServerSessionFactory { url, ssl in
            QBittorrentAPIService(baseURL: url, allowUntrustedSSL: ssl, transport: transport)
        })
        #expect(draft.profile == nil)
        #expect(draft.isNew)
        #expect(credentials.reads == 0)
        #expect(credentials.writes == 0)
        #expect(draft.connectionTestResult.isSuccess == (status == 200))
    }

    @Test("A failed deletion retains the profile and restores both credentials")
    func deleteRollback() throws {
        let context = try context()
        let profile = ServerProfile(host: "keep.local")
        context.insert(profile)
        try context.save()
        let credentials = DraftTestCredentials()
        credentials.passwords[profile.id] = "password"
        credentials.cookies[profile.id] = "cookie"
        let draft = ServerProfileDraft(profile: profile, credentials: credentials)
        #expect(!draft.delete(in: context, persist: { _ in throw DraftTestError.failed }))
        #expect(draft.profile === profile)
        #expect(credentials.passwords[profile.id] == "password")
        #expect(credentials.cookies[profile.id] == "cookie")
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<ServerProfile>()) == 1)
    }

    @Test("Saving a new draft is independent of connection testing")
    func newSave() throws {
        let context = try context()
        let credentials = DraftTestCredentials()
        let draft = ServerProfileDraft(profile: nil, credentials: credentials)
        draft.name = "New"
        draft.host = "offline.local"
        draft.password = "secret"
        #expect(draft.save(in: context))
        let profile = try #require(draft.profile)
        #expect(profile.host == "offline.local")
        #expect(credentials.passwords[profile.id] == "secret")
        #expect(try context.fetchCount(FetchDescriptor<ServerProfile>()) == 1)
        #expect(!context.hasChanges)
    }

    @Test("Failed saves restore profile fields and scoped credentials", arguments: [false, true])
    func rollback(existing: Bool) throws {
        let context = try context()
        let credentials = DraftTestCredentials()
        let profile = existing ? ServerProfile(host: "old.local", isActive: true) : nil
        if let profile {
            context.insert(profile)
            try context.save()
            credentials.passwords[profile.id] = "old-password"
            credentials.cookies[profile.id] = "old-cookie"
        }
        let draft = ServerProfileDraft(profile: profile, credentials: credentials)
        let originalDate = profile?.lastUpdated
        draft.host = "changed.local"
        draft.password = "new-password"
        #expect(!draft.save(in: context, persist: { _ in throw DraftTestError.failed }))
        #expect(draft.error != nil)
        #expect(profile?.host == (existing ? "old.local" : nil))
        #expect(profile?.lastUpdated == originalDate)
        #expect(credentials.passwords.count == (existing ? 1 : 0))
        #expect(credentials.cookies.count == (existing ? 1 : 0))
        if let profile { #expect(credentials.passwords[profile.id] == "old-password") }
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<ServerProfile>()) == (existing ? 1 : 0))
    }

    @Test("Credential failure prevents profile persistence")
    func credentialFailure() throws {
        let context = try context()
        let credentials = DraftTestCredentials()
        let profile = ServerProfile(host: "old.local")
        context.insert(profile)
        try context.save()
        credentials.passwords[profile.id] = "original"
        let draft = ServerProfileDraft(profile: profile, credentials: credentials)
        draft.host = "changed.local"
        credentials.failNextWrite = true
        #expect(!draft.save(in: context))
        #expect(profile.host == "old.local")
        #expect(credentials.passwords[profile.id] == "original")
        #expect(!context.hasChanges)
    }

    @Test("Successful edits invalidate stale cookies and signal reconnect; deletion cleans only this profile")
    func updateAndDelete() throws {
        let context = try context()
        let profile = ServerProfile(host: "old.local", isActive: true, lastUpdated: .distantPast)
        context.insert(profile)
        try context.save()
        let credentials = DraftTestCredentials()
        let other = UUID()
        credentials.passwords = [profile.id: "old", other: "other"]
        credentials.cookies = [profile.id: "stale", other: "other"]
        let draft = ServerProfileDraft(profile: profile, credentials: credentials)
        #expect(draft.host == "old.local")
        #expect(draft.password == "old")
        draft.host = "new.local"
        draft.password = "new"
        #expect(draft.save(in: context))
        #expect(profile.lastUpdated > .distantPast)
        #expect(profile.isActive)
        #expect(credentials.cookies[profile.id] == nil)
        #expect(draft.delete(in: context))
        #expect(try context.fetchCount(FetchDescriptor<ServerProfile>()) == 0)
        #expect(credentials.passwords == [other: "other"])
        #expect(credentials.cookies == [other: "other"])
    }

    private func context() throws -> ModelContext {
        let container = try ModelContainer(for: ServerProfile.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }
}

enum DraftTestError: Error { case failed }

@MainActor
final class DraftTestCredentials: ServerProfileCredentials {
    var passwords: [UUID: String] = [:]
    var cookies: [UUID: String] = [:]
    var reads = 0
    var writes = 0
    var failNextWrite = false
    func password(for id: UUID) throws -> String? { reads += 1; return passwords[id] }
    func cookie(for id: UUID) throws -> String? { reads += 1; return cookies[id] }
    func setPassword(_ value: String?, for id: UUID) throws {
        writes += 1
        if failNextWrite { failNextWrite = false; throw DraftTestError.failed }
        passwords[id] = value
    }
    func setCookie(_ value: String?, for id: UUID) throws { writes += 1; cookies[id] = value }
}
