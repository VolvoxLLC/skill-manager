import Foundation

public enum AgentTargetKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case claudeCode
    case codex
    case githubCopilot
    case genericFilesystem

    public var id: String { rawValue }
}

public enum InstallScope: String, Codable, Sendable {
    case global
    case project
}

public enum InstallMode: String, Codable, Sendable {
    case copy
}

public struct AgentTarget: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let kind: AgentTargetKind
    public var displayName: String
    public var installPath: URL
    public var scope: InstallScope
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        kind: AgentTargetKind,
        displayName: String,
        installPath: URL,
        scope: InstallScope,
        isEnabled: Bool
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.installPath = installPath
        self.scope = scope
        self.isEnabled = isEnabled
    }
}
