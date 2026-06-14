import Foundation
import SkillDeckCore

public enum DefaultAgentAdapters {
    public static func claudeCode(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> AgentTargetAdapter {
        AgentTargetAdapter(
            kind: .claudeCode,
            displayName: "Claude Code",
            defaultGlobalInstallPath: homeDirectory.appendingPathComponent(".claude/skills", isDirectory: true),
            projectInstallDirectoryName: ".claude/skills",
            supportsEnableDisable: false
        )
    }

    public static func codex(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> AgentTargetAdapter {
        AgentTargetAdapter(
            kind: .codex,
            displayName: "Codex",
            defaultGlobalInstallPath: homeDirectory.appendingPathComponent(".codex/skills", isDirectory: true),
            projectInstallDirectoryName: ".agents/skills",
            supportsEnableDisable: false
        )
    }

    public static func githubCopilot(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> AgentTargetAdapter {
        AgentTargetAdapter(
            kind: .githubCopilot,
            displayName: "GitHub Copilot",
            defaultGlobalInstallPath: homeDirectory.appendingPathComponent(".copilot/skills", isDirectory: true),
            projectInstallDirectoryName: ".agents/skills",
            supportsEnableDisable: false
        )
    }

    public static var all: [AgentTargetAdapter] {
        [claudeCode(), codex(), githubCopilot()]
    }
}
