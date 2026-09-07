import Foundation

@MainActor
protocol QBittorrentAPIServiceProtocol: AnyObject, Sendable {
    func getTorrents(filter: TorrentFilter) async throws -> [Torrent]
    func getGlobalStats() async throws -> GlobalStats
    func getDefaultSavePath() async throws -> String
    func getTorrentCategories() async throws -> [String: QBittorrentAPIService.TorrentCategory]
    func getPreferences() async throws -> ServerPreferences
    func setPreferences(_ preferences: ServerPreferences) async throws
    
    func addTorrentByURL(_ magnetOrURL: String, savePath: String) async throws
    func addTorrentByData(_ data: Data, filename: String, savePath: String) async throws
    
    func pauseTorrents(hashes: [String]) async throws
    func resumeTorrents(hashes: [String]) async throws
    func deleteTorrents(hashes: [String], deleteFiles: Bool) async throws
    func setTorrentLocation(hashes: [String], location: String) async throws
    func setTorrentCategory(hashes: [String], category: String) async throws
    
    func getTorrentTags() async throws -> [String]
    func addTorrentTags(hashes: [String], tags: [String]) async throws
    func removeTorrentTags(hashes: [String], tags: [String]) async throws
}
