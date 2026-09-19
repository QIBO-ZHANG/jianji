import Foundation

/// The error type every layer surfaces. Views switch on `kind` for UI decisions and
/// use `userMessage` for copy, so business codes never leak into string comparisons.
struct AppError: Error, Equatable, Sendable {
    enum Kind: String, Equatable, Sendable {
        case cancelled
        case transport
        case unauthorized
        case forbidden
        case notFound
        case rateLimited
        case client
        case server
        case decoding
        case unsupported
        case unknown
    }

    var kind: Kind
    var message: String?
    var statusCode: Int?
    var businessCode: String?

    init(kind: Kind, message: String? = nil, statusCode: Int? = nil, businessCode: String? = nil) {
        self.kind = kind
        self.message = message
        self.statusCode = statusCode
        self.businessCode = businessCode
    }

    var isRetryable: Bool {
        switch kind {
        case .transport, .rateLimited, .server: true
        case .cancelled, .unauthorized, .forbidden, .notFound, .client, .decoding, .unsupported, .unknown: false
        }
    }

    var userMessage: String {
        if let message, !message.isEmpty { return message }
        return switch kind {
        case .cancelled: "Request cancelled."
        case .transport: "Network unavailable. Check your connection and try again."
        case .unauthorized: "Please sign in again."
        case .forbidden: "You do not have access to this resource."
        case .notFound: "Not found."
        case .rateLimited: "Too many requests. Please wait a moment."
        case .client: "The request was rejected."
        case .server: "Something went wrong on our side."
        case .decoding: "Unexpected response from the server."
        case .unsupported: "This action is not supported yet."
        case .unknown: "Something went wrong."
        }
    }

    static func from(statusCode: Int, message: String? = nil, businessCode: String? = nil) -> AppError {
        let kind: Kind = switch statusCode {
        case 401: .unauthorized
        case 403: .forbidden
        case 404: .notFound
        case 429: .rateLimited
        case 400..<500: .client
        case 500...: .server
        default: .unknown
        }
        return AppError(kind: kind, message: message, statusCode: statusCode, businessCode: businessCode)
    }
}
