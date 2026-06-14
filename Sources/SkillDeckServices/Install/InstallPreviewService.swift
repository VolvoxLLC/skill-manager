import Foundation
import SkillDeckCore

public struct InstallPreview: Equatable, Sendable {
    public let skillName: String
    public let destinations: [URL]
    public let installMode: InstallMode
    public let backupRequired: Bool

    public init(skillName: String, destinations: [URL], installMode: InstallMode, backupRequired: Bool) {
        self.skillName = skillName
        self.destinations = destinations
        self.installMode = installMode
        self.backupRequired = backupRequired
    }
}

public struct InstallPreviewService: Sendable {
    private let folderGrants: FolderGrantChecking

    public init(folderGrants: FolderGrantChecking) {
        self.folderGrants = folderGrants
    }

    public func previewInstall(skill: SkillDetail, targets: [AgentTarget]) async throws -> InstallPreview {
        var destinations: [URL] = []

        for target in targets where target.isEnabled {
            let destination = target.installPath
                .appendingPathComponent(skill.summary.name, isDirectory: true)
                .appendingPathComponent("SKILL.md")

            guard try folderGrants.canWrite(to: destination) else {
                throw SkillDeckError.folderGrantMissing(target.installPath.path)
            }
            destinations.append(destination)
        }

        return InstallPreview(
            skillName: skill.summary.name,
            destinations: destinations,
            installMode: .copy,
            backupRequired: true
        )
    }
}
