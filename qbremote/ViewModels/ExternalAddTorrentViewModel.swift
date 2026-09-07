import Foundation

/// Prepares the selected destination without changing the app's active profile.
@Observable
final class ExternalAddTorrentViewModel {
    private(set) var session: QBServerSession?
    private(set) var error: String?

    func prepare(
        profile: ServerProfile,
        injectedService: (any QBittorrentAPIServiceProtocol)? = nil,
        credentials: (any QBSessionCredentials)? = nil
    ) async {
        session = nil
        error = nil
        guard profile.baseURL != nil else {
            error = "Invalid Server URL"
            return
        }
        do {
            let session = try QBServerSession(profile: profile, service: injectedService, credentials: credentials)
            _ = try await session.run(.globalStats)
            try Task.checkCancellation()
            self.session = session
        } catch is CancellationError {
            return
        } catch let error as QBError {
            self.error = error.errorDescription ?? "Login failed."
        } catch {
            self.error = error.localizedDescription
        }
    }
}
