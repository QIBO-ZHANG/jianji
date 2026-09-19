import Foundation

/// A declarative description of one HTTP call. Endpoints are value types so a feature
/// can build them in one line and keep URL composition out of view code.
struct Endpoint: Sendable {
    enum Method: String, Sendable {
        case get = "GET", post = "POST", put = "PUT", patch = "PATCH", delete = "DELETE"

        var allowsBody: Bool { self != .get && self != .delete }
    }

    var path: String
    var method: Method = .get
    var query: [String: String] = [:]
    var body: Data?
    var headers: [String: String] = [:]
    var timeout: TimeInterval?
    var requiresAuth = false

    func urlRequest(baseURL: URL, defaultTimeout: TimeInterval) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        else { throw AppError(kind: .unsupported, message: "Invalid URL") }

        if !query.isEmpty {
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw AppError(kind: .unsupported, message: "Invalid URL") }

        var request = URLRequest(url: url, timeoutInterval: timeout ?? defaultTimeout)
        request.httpMethod = method.rawValue
        request.httpBody = method.allowsBody ? body : nil
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        return request
    }
}

struct EmptyResponse: Decodable, Sendable {}
