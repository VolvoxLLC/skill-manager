import Foundation
import OSLog

public struct AppLogEntry: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let category: String
    public let level: String
    public let message: String
    public let createdAt: Date
}

public final actor InMemoryAppLogService {
    private var storedEntries: [AppLogEntry] = []

    public init() {}

    public func info(category: String, message: String) {
        storedEntries.insert(
            AppLogEntry(id: UUID(), category: category, level: "Info", message: redact(message), createdAt: Date()),
            at: 0
        )
    }

    public func entries() -> [AppLogEntry] {
        storedEntries
    }

    private func redact(_ message: String) -> String {
        message.replacingOccurrences(
            of: #"/Users/[^ ]+/(.+/[^/]+)$"#,
            with: "<path>/$1",
            options: .regularExpression
        )
    }
}
