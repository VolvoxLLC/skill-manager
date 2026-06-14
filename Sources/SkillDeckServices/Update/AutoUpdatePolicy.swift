import Foundation

public enum AutoUpdateDecision: Equatable, Sendable {
    case allow
    case refuse(reason: String)
}

public enum AutoUpdatePolicy {
    public static func evaluate(
        isSourceTrusted: Bool,
        hasFolderGrant: Bool,
        hasLocalModifications: Bool,
        hasStableSourceHash: Bool,
        backupCanBeCreated: Bool
    ) -> AutoUpdateDecision {
        guard isSourceTrusted else { return .refuse(reason: "Source is not trusted.") }
        guard hasFolderGrant else { return .refuse(reason: "Folder access is missing.") }
        guard !hasLocalModifications else { return .refuse(reason: "Local modifications require manual review.") }
        guard hasStableSourceHash else { return .refuse(reason: "Source hash is not stable.") }
        guard backupCanBeCreated else { return .refuse(reason: "Backup cannot be created.") }
        return .allow
    }
}
