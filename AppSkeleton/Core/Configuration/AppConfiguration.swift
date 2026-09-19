import Foundation

/// Build-time configuration resolved per environment.
enum AppEnvironment: String, CaseIterable, Sendable {
    case development
    case staging
    case production

    static var current: AppEnvironment {
        if let override = ProcessInfo.processInfo.environment["APP_ENV"],
           let value = AppEnvironment(rawValue: override) {
            return value
        }
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }

    var baseURL: URL {
        return switch self {
        case .development: URL(string: "https://dev.api.example.com/v1")!
        case .staging: URL(string: "https://staging.api.example.com/v1")!
        case .production: URL(string: "https://api.example.com/v1")!
        }
    }

    var apiKey: String? {
        // Real secrets belong in Keychain or a git-ignored generated file, never here.
        Bundle.main.object(forInfoDictionaryKey: "APIKey") as? String
    }
}

struct AppConfiguration: Sendable {
    let environment: AppEnvironment
    let apiTimeout: TimeInterval
    let logLevel: AppLogger.Level

    static func live() -> AppConfiguration {
        let environment = AppEnvironment.current
        return AppConfiguration(
            environment: environment,
            apiTimeout: environment == .production ? 30 : 15,
            logLevel: environment == .production ? .info : .debug
        )
    }
}
