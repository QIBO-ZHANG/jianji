import SwiftUI

/// Composition root for the long-lived services. Features receive capabilities from here
/// instead of reaching for globals, so swapping an implementation stays a one-line change.
struct ServiceContainer: Sendable {
    let configuration: AppConfiguration
    let logger: AppLogger
    let api: APIClient
    let store: KeyValueStore

    init(
        configuration: AppConfiguration,
        logger: AppLogger,
        transport: any HTTPTransport,
        credentials: any CredentialProviding = AnonymousCredentials(),
        store: KeyValueStore = KeyValueStore()
    ) {
        self.configuration = configuration
        self.logger = logger
        self.store = store
        self.api = APIClient(
            transport: transport,
            baseURL: configuration.environment.baseURL,
            defaultTimeout: configuration.apiTimeout,
            credentials: credentials,
            logger: logger.scope("network")
        )
    }

    static func live() -> ServiceContainer {
        let configuration = AppConfiguration.live()
        return ServiceContainer(
            configuration: configuration,
            logger: AppLogger(minimum: configuration.logLevel).scope("app"),
            transport: URLSessionTransport()
        )
    }

    /// Offline container with deterministic responses. Drives previews and unit tests.
    static func stub(responses: [String: HTTPResponse] = [:]) -> ServiceContainer {
        let configuration = AppConfiguration(
            environment: .development,
            apiTimeout: 5,
            logLevel: .debug
        )
        return ServiceContainer(
            configuration: configuration,
            logger: AppLogger(minimum: configuration.logLevel),
            transport: StubTransport { request in
                let path = request.url?.path ?? ""
                if let match = responses.first(where: { path.hasSuffix($0.key) }) { return match.value }
                return HTTPResponse(statusCode: 200, data: Data("{}".utf8))
            },
            store: KeyValueStore(defaults: UserDefaults(suiteName: "skeleton.stub") ?? .standard)
        )
    }
}

private struct ServicesKey: EnvironmentKey {
    static let defaultValue = ServiceContainer.stub()
}

extension EnvironmentValues {
    var services: ServiceContainer {
        get { self[ServicesKey.self] }
        set { self[ServicesKey.self] = newValue }
    }
}

extension View {
    func services(_ container: ServiceContainer) -> some View {
        environment(\.services, container)
    }
}
