import Foundation
import SkillDeckCore

public struct AgentTargetAdapter: Hashable, Sendable {
    public let kind: AgentTargetKind
    public let displayName: String
    public let defaultGlobalInstallPath: URL
    public let projectInstallDirectoryName: String
    public let supportsEnableDisable: Bool

    public init(
        kind: AgentTargetKind,
        displayName: String,
        defaultGlobalInstallPath: URL,
        projectInstallDirectoryName: String,
        supportsEnableDisable: Bool
    ) {
        self.kind = kind
        self.displayName = displayName
        self.defaultGlobalInstallPath = defaultGlobalInstallPath
        self.projectInstallDirectoryName = projectInstallDirectoryName
        self.supportsEnableDisable = supportsEnableDisable
    }
}
