import Foundation

/// Shared URL policy for saved profiles and unsaved connection tests.
nonisolated enum QBServerURL {
    static func make(host: String, port: Int?, useHTTPS: Bool) -> URL? {
        let scheme = useHTTPS ? "https" : "http"
        return URL(string: "\(scheme)://\(host)\(port.map { ":\($0)" } ?? "")")
    }
}
