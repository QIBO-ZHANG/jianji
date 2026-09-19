import Foundation

/// Seam for whoever owns tokens later. The skeleton ships an anonymous implementation so
/// `requiresAuth` stays meaningful without pulling in an account system.
protocol CredentialProviding: Sendable {
    func accessToken() async -> String?
}

struct AnonymousCredentials: CredentialProviding {
    func accessToken() async -> String? { nil }
}

/// Turns an `Endpoint` into a decoded model, mapping every failure onto `AppError`.
/// Feature code should depend on this, never on `URLSession` directly.
struct APIClient: Sendable {
    private let transport: any HTTPTransport
    private let baseURL: URL
    private let defaultTimeout: TimeInterval
    private let credentials: any CredentialProviding
    private let logger: AppLogger

    init(
        transport: any HTTPTransport,
        baseURL: URL,
        defaultTimeout: TimeInterval = 15,
        credentials: any CredentialProviding = AnonymousCredentials(),
        logger: AppLogger = AppLogger(category: "network")
    ) {
        self.transport = transport
        self.baseURL = baseURL
        self.defaultTimeout = defaultTimeout
        self.credentials = credentials
        self.logger = logger
    }

    @discardableResult
    func execute(_ endpoint: Endpoint) async throws -> HTTPResponse {
        var request = try endpoint.urlRequest(baseURL: baseURL, defaultTimeout: defaultTimeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if endpoint.body != nil, request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if endpoint.requiresAuth {
            guard let token = await credentials.accessToken() else {
                throw AppError(kind: .unauthorized, businessCode: "missing_token")
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        logger.debug("\(endpoint.method.rawValue) \(endpoint.path)")
        do {
            let response = try await transport.send(request)
            guard (200..<300).contains(response.statusCode) else {
                throw AppError.from(statusCode: response.statusCode, message: Self.serverMessage(in: response.data))
            }
            return response
        } catch let error as AppError {
            logger.error("request failed", error)
            throw error
        } catch is CancellationError {
            throw AppError(kind: .cancelled)
        } catch let error as URLError {
            logger.error("transport failed", error)
            throw AppError(kind: .transport, message: error.localizedDescription)
        } catch {
            logger.error("unexpected failure", error)
            throw AppError(kind: .unknown, message: error.localizedDescription)
        }
    }

    func fetch<Value: Decodable & Sendable>(_ type: Value.Type, from endpoint: Endpoint) async throws -> Value {
        let response = try await execute(endpoint)
        if type == EmptyResponse.self, let empty = EmptyResponse() as? Value { return empty }
        return try decode(type, from: response.data)
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        do {
            return try Self.makeDecoder().decode(type, from: data)
        } catch {
            logger.error("decode failed", error)
            throw AppError(kind: .decoding, message: String(describing: error))
        }
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func serverMessage(in data: Data) -> String? {
        struct Payload: Decodable { let message: String }
        return (try? JSONDecoder().decode(Payload.self, from: data))?.message
    }
}
