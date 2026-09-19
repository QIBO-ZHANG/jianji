import XCTest
@testable import AppSkeleton

final class CoreLayerTests: XCTestCase {
    private var services: ServiceContainer!

    override func setUp() {
        super.setUp()
        services = .stub()
    }

    func testEnvironmentResolvesBaseURL() {
        for environment in AppEnvironment.allCases {
            XCTAssertTrue(environment.baseURL.absoluteString.hasPrefix("https://"))
        }
    }

    func testEndpointBuildsRequestWithSortedQuery() throws {
        let endpoint = Endpoint(path: "orders", query: ["b": "2", "a": "1"])
        let request = try endpoint.urlRequest(
            baseURL: URL(string: "https://api.example.com/v1")!,
            defaultTimeout: 10
        )

        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/orders?a=1&b=2")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertNil(request.httpBody)
        XCTAssertEqual(request.timeoutInterval, 10)
    }

    func testStatusCodesMapToErrorKinds() {
        XCTAssertEqual(AppError.from(statusCode: 401).kind, .unauthorized)
        XCTAssertEqual(AppError.from(statusCode: 404).kind, .notFound)
        XCTAssertEqual(AppError.from(statusCode: 429).kind, .rateLimited)
        XCTAssertEqual(AppError.from(statusCode: 503).kind, .server)
        XCTAssertTrue(AppError(kind: .server).isRetryable)
        XCTAssertFalse(AppError(kind: .forbidden).isRetryable)
    }

    func testClientMapsUnauthorizedResponse() async throws {
        let stub = ServiceContainer.stub(responses: [
            "profile": HTTPResponse(statusCode: 401, data: Data(#"{"message":"gone"}"#.utf8)),
        ])
        do {
            struct Profile: Decodable, Sendable { let id: String }
            _ = try await stub.api.fetch(Profile.self, from: Endpoint(path: "profile"))
            XCTFail("expected a failure")
        } catch let error as AppError {
            XCTAssertEqual(error.kind, .unauthorized)
            XCTAssertEqual(error.message, "gone")
            XCTAssertEqual(error.statusCode, 401)
        }
    }

    func testRequiresAuthWithoutTokenFailsBeforeTransport() async {
        let endpoint = Endpoint(path: "profile", requiresAuth: true)
        do {
            struct Profile: Decodable, Sendable { let id: String }
            _ = try await services.api.fetch(Profile.self, from: endpoint)
            XCTFail("expected a failure")
        } catch let error as AppError {
            XCTAssertEqual(error.kind, .unauthorized)
            XCTAssertEqual(error.businessCode, "missing_token")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testDecodeFailureBecomesDecodingError() async {
        let stub = ServiceContainer.stub(responses: [
            "profile": HTTPResponse(statusCode: 200, data: Data(#"{"id":42}"#.utf8)),
        ])
        struct Profile: Decodable, Sendable { let id: String }
        do {
            _ = try await stub.api.fetch(Profile.self, from: Endpoint(path: "profile"))
            XCTFail("expected a failure")
        } catch let error as AppError {
            XCTAssertEqual(error.kind, .decoding)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testKeyValueStoreRoundTripsTypedKeys() {
        let suite = UserDefaults(suiteName: name)!
        let store = KeyValueStore(defaults: suite)
        let key = KeyValueStore.BoolKey.hasCompletedOnboarding

        XCTAssertEqual(store[key], false)
        store[key] = true
        XCTAssertEqual(store[key], true)
        store.clear(key)
        XCTAssertEqual(store[key], false)
        suite.removePersistentDomain(forName: name)
    }

    @MainActor
    func testRouterStackIntents() {
        let router = AppRouter()
        router.push(.scaffoldCheck)
        router.push(.scaffoldCheck)
        XCTAssertEqual(router.path.count, 2)

        router.pop()
        XCTAssertEqual(router.path.count, 1)

        router.replaceTop(with: .scaffoldCheck)
        XCTAssertEqual(router.path.count, 1)

        router.popToRoot()
        XCTAssertTrue(router.path.isEmpty)
    }

    @MainActor
    func testRouterOpensKnownDeepLinkOnly() {
        let router = AppRouter()
        XCTAssertTrue(router.open(URL(string: "appskeleton://scaffold")!))
        XCTAssertEqual(router.path, [.scaffoldCheck])

        router.popToRoot()
        XCTAssertFalse(router.open(URL(string: "appskeleton://unknown-path")!))
        XCTAssertTrue(router.path.isEmpty)
    }
}
