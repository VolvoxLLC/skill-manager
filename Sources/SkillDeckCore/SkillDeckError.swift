import Foundation

public enum SkillDeckError: Error, Equatable, Sendable, LocalizedError {
    case sourceUnavailable(String)
    case githubRateLimited
    case invalidSkillStructure(String)
    case folderGrantMissing(String)
    case folderGrantExpired(String)
    case writePermissionDenied(String)
    case pathTraversalRejected(String)
    case localModificationDetected(String)
    case backupFailed(String)
    case hashMismatchAfterWrite(expected: String, actual: String)
    case telemetryConsentMissing

    public var errorDescription: String? {
        switch self {
        case .sourceUnavailable(let source): "Source unavailable: \(source)"
        case .githubRateLimited: "GitHub rate limit reached."
        case .invalidSkillStructure(let reason): "Invalid skill structure: \(reason)"
        case .folderGrantMissing(let path): "Folder access is missing for \(path)."
        case .folderGrantExpired(let path): "Folder access expired for \(path)."
        case .writePermissionDenied(let path): "Write permission denied for \(path)."
        case .pathTraversalRejected(let path): "Unsafe path rejected: \(path)."
        case .localModificationDetected(let path): "Local modifications detected at \(path)."
        case .backupFailed(let path): "Backup failed for \(path)."
        case .hashMismatchAfterWrite: "The written file hash did not match the expected hash."
        case .telemetryConsentMissing: "Telemetry consent has not been granted."
        }
    }
}
