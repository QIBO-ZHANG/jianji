import Foundation

struct HTTPResponse: Sendable {
    let statusCode: Int
    let data: Data
    let headers: [String: String]

    init(statusCode: Int, data: Data = Data(), headers: [String: String] = [:]) {
        self.statusCode = statusCode
        self.data = data
        self.headers = headers
    }

    init?(response: URLResponse, data: Data) {
        guard let http = response as? HTTPURLResponse else { return nil }
        self.statusCode = http.statusCode
        self.data = data
        self.headers = http.allHeaderFields.reduce(into: [:]) { result, pair in
            guard let key = pair.key as? String, let value = pair.value as? String else { return }
            result[key] = value
        }
    }
}

/// Abstraction over the network so tests and SwiftUI previews can drive every call path
/// without a live backend.
protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPResponse
}

struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        let (data, response) = try await session.data(for: request)
        guard let result = HTTPResponse(response: response, data: data) else {
            throw URLError(.unsupportedURL)
        }
        return result
    }
}

/// Returns canned responses per path prefix. Used by previews and unit tests.
struct StubTransport: HTTPTransport {
    let handler: @Sendable (URLRequest) async throws -> HTTPResponse

    init(_ handler: @escaping @Sendable (URLRequest) async throws -> HTTPResponse) {
        self.handler = handler
    }

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        try await handler(request)
    }
}
