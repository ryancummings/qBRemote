import Foundation
import Testing
@testable import qbremote

@MainActor
struct QBittorrentAPIServiceTests {
    final class DeterministicTransport: QBittorrentTransport {
        typealias Handler = (URLRequest) throws -> (Data, URLResponse)

        private(set) var requests: [URLRequest] = []
        var handler: Handler

        init(handler: @escaping Handler) {
            self.handler = handler
        }

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            requests.append(request)
            return try handler(request)
        }
    }

    private let baseURL = URL(string: "http://localhost:8080")!

    @Test("Production transport disables automatic cookie handling")
    func productionTransportDisablesCookies() {
        let transport = URLSessionQBittorrentTransport(allowUntrustedSSL: false)

        #expect(transport.configuration.httpCookieAcceptPolicy == .never)
    }

    @Test("Authenticated requests include the Referer and manual SID cookie")
    func authenticatedHeaders() async throws {
        let transport = makeTransport(data: Data("[]".utf8))
        let service = makeService(transport: transport)
        service.setSessionCookie("test-session")

        _ = try await service.getTorrents(filter: .active)

        let request = try #require(transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "Referer") == baseURL.absoluteString)
        #expect(request.value(forHTTPHeaderField: "Cookie") == "SID=test-session")
        #expect(URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?.queryItems == [
            URLQueryItem(name: "filter", value: "active")
        ])
    }

    @Test("Login uses form encoding and stores the returned SID")
    func loginFormEncoding() async throws {
        let transport = makeTransport(
            data: Data("Ok.".utf8),
            headers: ["Set-Cookie": "SID=server-session; Path=/"]
        )
        let service = makeService(transport: transport)

        let sid = try await service.login(username: "user+name", password: "p&ss word")

        #expect(sid == "server-session")
        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
        #expect(String(data: try #require(request.httpBody), encoding: .utf8) == "username=user%2Bname&password=p%26ss%20word")
    }

    @Test("Login accepts Ok without an SID cookie")
    func loginWithoutSID() async throws {
        let service = makeService(transport: makeTransport(data: Data("Ok.".utf8)))

        #expect(try await service.login(username: "admin", password: "admin") == "")
    }

    @Test("Torrent URL and save path use form encoding")
    func addTorrentByURLFormEncoding() async throws {
        let transport = makeTransport()
        let service = makeService(transport: transport)
        service.setSessionCookie("sid")

        try await service.addTorrentByURL(
            "magnet:?xt=urn:btih:abc&dn=Some File",
            savePath: "/media/TV & Film"
        )

        let request = try #require(transport.requests.first)
        #expect(String(data: try #require(request.httpBody), encoding: .utf8) ==
                "urls=magnet%3A%3Fxt%3Durn%3Abtih%3Aabc%26dn%3DSome%20File&savepath=%2Fmedia%2FTV%20%26%20Film")
    }

    @Test("Torrent data uses a multipart upload")
    func addTorrentByDataMultipartEncoding() async throws {
        let transport = makeTransport()
        let service = makeService(transport: transport)
        service.setSessionCookie("sid")
        let torrentData = Data([0x00, 0x01, 0x02, 0xff])

        try await service.addTorrentByData(
            torrentData,
            filename: "sample.torrent",
            savePath: "/downloads"
        )

        let request = try #require(transport.requests.first)
        let contentType = try #require(request.value(forHTTPHeaderField: "Content-Type"))
        let boundary = try #require(contentType.split(separator: "boundary=").last.map(String.init))
        let body = try #require(request.httpBody)
        #expect(body.range(of: torrentData) != nil)
        let bodyText = String(decoding: body, as: UTF8.self)
        #expect(bodyText.contains("--\(boundary)\r\n"))
        #expect(bodyText.contains("name=\"torrents\"; filename=\"sample.torrent\""))
        #expect(bodyText.contains("Content-Type: application/x-bittorrent"))
        #expect(bodyText.contains("name=\"savepath\"\r\n\r\n/downloads\r\n"))
        #expect(bodyText.hasSuffix("--\(boundary)--\r\n"))
    }

    @Test("Authenticated HTTP errors map to QBError")
    func authenticatedHTTPErrorMapping() async throws {
        for (statusCode, expectedDescription) in [
            (401, "Unauthorized (401). Check credentials or reverse proxy headers."),
            (403, "Forbidden (403). Session expired, IP banned, or invalid subnet."),
            (500, "Request failed with HTTP 500.")
        ] {
            let service = makeService(transport: makeTransport(statusCode: statusCode))

            do {
                _ = try await service.getPreferences()
                Issue.record("Expected getPreferences to throw for HTTP \(statusCode)")
            } catch let error as QBError {
                #expect(error.errorDescription == expectedDescription)
            }
        }
    }

    @Test("Invalid JSON maps to a decoding error")
    func decodingFailure() async throws {
        let service = makeService(transport: makeTransport(data: Data("not-json".utf8)))

        do {
            _ = try await service.getPreferences()
            Issue.record("Expected getPreferences to throw")
        } catch let error as QBError {
            guard case .decodingFailed = error else {
                Issue.record("Expected decodingFailed, got \(error)")
                return
            }
        }
    }

    @Test("Categories accept an empty array")
    func categoriesAcceptEmptyArray() async throws {
        let service = makeService(transport: makeTransport(data: Data("[]".utf8)))

        #expect(try await service.getTorrentCategories().isEmpty)
    }

    @Test("Tags return an empty list when the endpoint fails")
    func tagsFailureReturnsEmptyList() async throws {
        let service = makeService(transport: makeTransport(statusCode: 500))

        #expect(try await service.getTorrentTags().isEmpty)
    }

    private func makeService(transport: DeterministicTransport) -> QBittorrentAPIService {
        QBittorrentAPIService(baseURL: baseURL, transport: transport)
    }

    private func makeTransport(
        statusCode: Int = 200,
        data: Data = Data(),
        headers: [String: String]? = nil
    ) -> DeterministicTransport {
        DeterministicTransport { [baseURL] request in
            let response = HTTPURLResponse(
                url: request.url ?? baseURL,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: headers
            )!
            return (data, response)
        }
    }
}
