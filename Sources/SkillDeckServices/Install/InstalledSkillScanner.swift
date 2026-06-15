import Foundation
import SkillDeckCore

public struct InstalledSkillScanRoot: Equatable, Sendable {
    public let url: URL
    public let targetKind: AgentTargetKind
    public let displayName: String

    public init(url: URL, targetKind: AgentTargetKind, displayName: String) {
        self.url = url
        self.targetKind = targetKind
        self.displayName = displayName
    }
}

public struct ScannedInstalledSkill: Equatable, Sendable {
    public let name: String
    public let description: String
    public let targetKind: AgentTargetKind
    public let targetDisplayName: String
    public let rootURL: URL
    public let destination: URL
    public let skillMarkdown: String
    public let installedHash: String

    public init(
        name: String,
        description: String,
        targetKind: AgentTargetKind,
        targetDisplayName: String,
        rootURL: URL,
        destination: URL,
        skillMarkdown: String,
        installedHash: String
    ) {
        self.name = name
        self.description = description
        self.targetKind = targetKind
        self.targetDisplayName = targetDisplayName
        self.rootURL = rootURL
        self.destination = destination
        self.skillMarkdown = skillMarkdown
        self.installedHash = installedHash
    }
}

public struct InstalledSkillScanner: Sendable {
    public init() {}

    public static func defaultRoots(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> [InstalledSkillScanRoot] {
        [
            InstalledSkillScanRoot(
                url: homeDirectory.appendingPathComponent(".agents/skills", isDirectory: true),
                targetKind: .codex,
                displayName: "Agents"
            ),
            InstalledSkillScanRoot(
                url: homeDirectory.appendingPathComponent(".claude/skills", isDirectory: true),
                targetKind: .claudeCode,
                displayName: "Claude Code"
            ),
            InstalledSkillScanRoot(
                url: homeDirectory.appendingPathComponent(".codex/skills", isDirectory: true),
                targetKind: .codex,
                displayName: "Codex"
            ),
            InstalledSkillScanRoot(
                url: homeDirectory.appendingPathComponent(".copilot/skills", isDirectory: true),
                targetKind: .githubCopilot,
                displayName: "GitHub Copilot"
            )
        ]
    }

    public func scan(roots: [InstalledSkillScanRoot]) throws -> [ScannedInstalledSkill] {
        var scannedSkills: [ScannedInstalledSkill] = []

        for root in roots where FileManager.default.fileExists(atPath: root.url.path) {
            let skillFiles = try skillManifestURLs(inside: root.url)
            for skillFile in skillFiles {
                let markdown = try String(contentsOf: skillFile, encoding: .utf8)
                let manifest = try SkillManifestParser.parse(markdown)
                scannedSkills.append(
                    ScannedInstalledSkill(
                        name: manifest.name,
                        description: manifest.description,
                        targetKind: root.targetKind,
                        targetDisplayName: root.displayName,
                        rootURL: root.url,
                        destination: skillFile,
                        skillMarkdown: markdown,
                        installedHash: ContentHasher.sha256Hex(markdown)
                    )
                )
            }
        }

        return scannedSkills.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func skillManifestURLs(inside root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsPackageDescendants]
        ) else {
            return []
        }

        var skillFiles: [URL] = []
        for case let fileURL as URL in enumerator where fileURL.lastPathComponent == "SKILL.md" {
            skillFiles.append(fileURL)
        }

        return skillFiles.sorted { $0.path < $1.path }
    }
}
