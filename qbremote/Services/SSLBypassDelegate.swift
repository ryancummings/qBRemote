//
//  SSLBypassDelegate.swift
//  qbremote
//

import Foundation

/// URLSession delegate that bypasses SSL certificate validation.
/// Used specifically for user-configured local network servers that may
/// use self-signed certificates. Never use this for production HTTPS traffic.
final class SSLBypassDelegate: NSObject, URLSessionDelegate {

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        // Accept any certificate for local server connections
        let credential = URLCredential(trust: serverTrust)
        completionHandler(.useCredential, credential)
    }
}
