import XCTest
@testable import SkillDeckCore
@testable import SkillDeckServices

final class InstalledSkillScannerTests: XCTestCase {
    func testScansInstalledSkillsFromAgentFolders() throws {
        let root = try temporaryDirectory()
        let agentsRoot = root.appendingPathComponent(".agents/skills", isDirectory: true)
        let claudeRoot = root.appendingPathComponent(".claude/skills", isDirectory: true)
        try writeSkill(at: agentsRoot.appendingPathComponent("repo-helper/SKILL.md"), name: "repo-helper", description: "Repo helper")
        try writeSkill(at: claudeRoot.appendingPathComponent("swift/refactor/SKILL.md"), name: "swift-refactor", description: "Swift refactor")

        let scanner = InstalledSkillScanner()
        let installedSkills = try scanner.scan(roots: [
            InstalledSkillScanRoot(url: agentsRoot, targetKind: .codex, displayName: "Codex"),
            InstalledSkillScanRoot(url: claudeRoot, targetKind: .claudeCode, displayName: "Claude Code")
        ])

        XCTAssertEqual(installedSkills.map(\.name), ["repo-helper", "swift-refactor"])
        XCTAssertEqual(installedSkills[0].targetKind, .codex)
        XCTAssertEqual(installedSkills[1].targetKind, .claudeCode)
        XCTAssertTrue(installedSkills.allSatisfy { $0.installedHash.count == 64 })
    }

    func testDefaultRootsIncludeCommonAgentSkillFolders() {
        let roots = InstalledSkillScanner.defaultRoots(homeDirectory: URL(fileURLWithPath: "/Users/test", isDirectory: true))

        XCTAssertEqual(roots.map(\.url.path), [
            "/Users/test/.agents/skills",
            "/Users/test/.claude/skills",
            "/Users/test/.codex/skills",
            "/Users/test/.copilot/skills"
        ])
    }

    func testScanSkipsMalformedSkillFilesAndKeepsValidSkills() throws {
        let root = try temporaryDirectory()
        let agentsRoot = root.appendingPathComponent(".agents/skills", isDirectory: true)
        try writeSkill(at: agentsRoot.appendingPathComponent("valid/SKILL.md"), name: "valid", description: "Valid skill")
        let invalidFile = agentsRoot.appendingPathComponent("broken/SKILL.md")
        try FileManager.default.createDirectory(at: invalidFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "not frontmatter".write(to: invalidFile, atomically: true, encoding: .utf8)

        let scanner = InstalledSkillScanner()
        let installedSkills = try scanner.scan(roots: [
            InstalledSkillScanRoot(url: agentsRoot, targetKind: .codex, displayName: "Codex")
        ])

        XCTAssertEqual(installedSkills.map(\.name), ["valid"])
    }
}

private func writeSkill(at url: URL, name: String, description: String) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try """
    ---
    name: \(name)
    description: \(description)
    ---
    """.write(to: url, atomically: true, encoding: .utf8)
}

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
