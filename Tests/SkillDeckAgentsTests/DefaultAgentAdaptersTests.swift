import XCTest
@testable import SkillDeckAgents
@testable import SkillDeckCore

final class DefaultAgentAdaptersTests: XCTestCase {
    func testCodexDefaultPathUsesCodexSkillsFolder() {
        let adapter = DefaultAgentAdapters.codex(homeDirectory: URL(fileURLWithPath: "/Users/test", isDirectory: true))
        XCTAssertEqual(adapter.displayName, "Codex")
        XCTAssertEqual(adapter.defaultGlobalInstallPath.path, "/Users/test/.codex/skills")
        XCTAssertEqual(adapter.projectInstallDirectoryName, ".agents/skills")
    }

    func testClaudeDefaultPathUsesClaudeSkillsFolder() {
        let adapter = DefaultAgentAdapters.claudeCode(homeDirectory: URL(fileURLWithPath: "/Users/test", isDirectory: true))
        XCTAssertEqual(adapter.defaultGlobalInstallPath.path, "/Users/test/.claude/skills")
        XCTAssertEqual(adapter.projectInstallDirectoryName, ".claude/skills")
    }
}
