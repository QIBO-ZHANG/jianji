import Foundation
import os

/// Single entry point for logging. Every subsystem gets its own scope so filtered
/// Console output stays readable as the app grows.
struct AppLogger: Sendable {
    enum Level: Int, Comparable, Sendable {
        case debug, info, error

        static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    private let subsystem: String
    private let category: String
    private let logger: Logger
    private let minimum: Level

    init(subsystem: String = Bundle.main.bundleIdentifier ?? "app", category: String = "general", minimum: Level = .debug) {
        self.subsystem = subsystem
        self.category = category
        self.logger = Logger(subsystem: subsystem, category: category)
        self.minimum = minimum
    }

    func scope(_ category: String) -> AppLogger {
        AppLogger(subsystem: subsystem, category: category, minimum: minimum)
    }

    func log(_ level: Level, _ message: @autoclosure () -> String) {
        guard level >= minimum else { return }
        let text = message()
        switch level {
        case .debug: logger.debug("\(text, privacy: .private)")
        case .info: logger.info("\(text, privacy: .public)")
        case .error: logger.error("\(text, privacy: .public)")
        }
    }

    func debug(_ message: @autoclosure () -> String) { log(.debug, message()) }
    func info(_ message: @autoclosure () -> String) { log(.info, message()) }

    func error(_ message: @autoclosure () -> String, _ error: (any Error)? = nil) {
        guard let error else {
            log(.error, message())
            return
        }
        let text = message()
        let reflected = String(reflecting: error)
        logger.error("\(text, privacy: .public) — \(reflected, privacy: .public)")
    }
}
