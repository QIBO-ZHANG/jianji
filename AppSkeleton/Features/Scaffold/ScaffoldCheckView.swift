import SwiftUI

/// Not a business screen: it exercises each Core seam end to end so a regression in the
/// scaffolding shows up in the app itself, before any feature is written.
@MainActor
@Observable
final class ScaffoldCheckModel {
    struct Check: Identifiable {
        enum Status {
            case pending, passed, failed(String)
        }

        let name: String
        var status: Status = .pending
        var id: String { name }
    }

    private(set) var checks: [Check] = ["Configuration", "Request building", "Decoding", "Persistence", "Routing", "Logging"]
        .map { Check(name: $0) }
    private(set) var isRunning = false

    private let services: ServiceContainer
    private let endpoint = Endpoint(path: "scaffold/health", method: .get, query: ["trace": "1"])

    private struct Payload: Codable, Equatable {
        let healthy: Bool
        let sampledAt: Date
    }

    init(services: ServiceContainer) { self.services = services }

    func runAll() async {
        isRunning = true
        defer { isRunning = false }
        for index in checks.indices {
            checks[index].status = await Self.run(checks[index].name, services: services, endpoint: endpoint)
        }
    }

    private static func run(_ name: String, services: ServiceContainer, endpoint: Endpoint) async -> Check.Status {
        do {
            switch name {
            case "Configuration":
                guard services.configuration.environment.baseURL.scheme != nil else {
                    throw AppError(kind: .unsupported, message: "missing base URL")
                }
            case "Request building":
                let request = try endpoint.urlRequest(
                    baseURL: services.configuration.environment.baseURL,
                    defaultTimeout: services.configuration.apiTimeout
                )
                guard request.httpMethod == "GET", request.url?.query?.contains("trace=1") == true else {
                    throw AppError(kind: .unknown, message: "unexpected request")
                }
            case "Decoding":
                let stub = ServiceContainer.stub(responses: [
                    "scaffold/health": HTTPResponse(
                        statusCode: 200,
                        data: Data(#"{"healthy":true,"sampled_at":"2026-09-18T00:00:00Z"}"#.utf8)
                    ),
                ])
                let payload = try await stub.api.fetch(Payload.self, from: endpoint)
                guard payload.healthy else { throw AppError(kind: .server, message: "unhealthy") }
            case "Persistence":
                let key = KeyValueStore.StringKey.lastSyncedAt
                let marker = String(Date().timeIntervalSince1970)
                services.store.write(marker, key: key)
                guard services.store.read(key) == marker else {
                    throw AppError(kind: .unknown, message: "roundtrip mismatch")
                }
                services.store.clear(key)
            case "Routing":
                let router = AppRouter()
                router.push(.scaffoldCheck)
                router.pop()
                guard router.path.isEmpty else { throw AppError(kind: .unknown, message: "pop failed") }
            case "Logging":
                services.logger.info("scaffold self-check reached logging scope")
            default:
                throw AppError(kind: .unsupported, message: "unknown check")
            }
            return .passed
        } catch {
            services.logger.error("check \(name) failed", error)
            let reason = (error as? AppError)?.userMessage ?? String(describing: error)
            return .failed(reason)
        }
    }
}

struct ScaffoldCheckView: View {
    @Environment(\.services) private var services
    @State private var model: ScaffoldCheckModel?

    var body: some View {
        List {
            Section {
                ForEach(model?.checks ?? []) { check in
                    row(for: check)
                }
            } header: {
                Text("Core seams")
            } footer: {
                Text("Environment: \(services.configuration.environment.rawValue) · timeout \(Int(services.configuration.apiTimeout))s")
            }
        }
        .navigationTitle(AppRoute.scaffoldCheck.navigationTitle)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Rerun") {
                    Task { await model?.runAll() }
                }
                .disabled(model?.isRunning ?? true)
            }
        }
        .task { await ensureModel().runAll() }
        .refreshable { await model?.runAll() }
    }

    @MainActor
    private func ensureModel() -> ScaffoldCheckModel {
        if let model { return model }
        let created = ScaffoldCheckModel(services: services)
        model = created
        return created
    }

    @ViewBuilder
    private func row(for check: ScaffoldCheckModel.Check) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.medium.rawValue) {
            Image(systemName: check.status.symbolName)
                .foregroundStyle(check.status.tint)
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs.rawValue) {
                Text(check.name).font(Theme.Typography.body)
                if let reason = check.status.failureReason {
                    Text(reason).font(Theme.Typography.mono).foregroundStyle(Theme.Palette.secondaryLabel)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs.rawValue)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("scaffold.check.\(check.name)")
        .accessibilityValue(check.status.accessibilityName)
    }
}

private extension ScaffoldCheckModel.Check.Status {
    var accessibilityName: String {
        switch self {
        case .pending: "pending"
        case .passed: "passed"
        case .failed: "failed"
        }
    }

    var symbolName: String {
        switch self {
        case .pending: "clock"
        case .passed: "checkmark.circle.fill"
        case .failed: "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .pending: Theme.Palette.secondaryLabel
        case .passed: Theme.Palette.positive
        case .failed: Theme.Palette.negative
        }
    }

    var failureReason: String? {
        if case let .failed(reason) = self { return reason }
        return nil
    }
}

#Preview {
    NavigationStack {
        ScaffoldCheckView()
            .services(.stub())
            .environment(AppRouter())
    }
}
