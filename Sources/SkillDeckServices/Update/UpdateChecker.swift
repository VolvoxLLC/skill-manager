import Foundation

public enum UpdateCheckResult: Equatable, Sendable {
    case upToDate
    case updateAvailable
}

public enum UpdateChecker {
    public static func compare(installedHash: String, upstreamHash: String) -> UpdateCheckResult {
        installedHash == upstreamHash ? .upToDate : .updateAvailable
    }
}
