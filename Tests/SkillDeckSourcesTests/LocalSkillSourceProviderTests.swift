import XCTest
@testable import SkillDeckCore
@testable import SkillDeckSources

final class LocalSkillSourceProviderTests: XCTestCase {
    func testScansSupportedSkillLayouts() async throws {
        let root = try TemporaryDirectory()
        try root.write("SKILL.md", """
        ---
        name: root-skill
        description: Root skill
        ---
        """)
        try root.write("skills/frontend/SKILL.md", """
        ---
        name: frontend
        description: Frontend skill
        ---
        """)
        try root.write(".agents/skills/codex/SKILL.md", """
        ---
        name: codex
        description: Codex skill
        ---
        """)

        let provider = LocalSkillSourceProvider()
        let skills = try await provider.scanRepository(at: root.url, source: SkillSourceReference(kind: .local, location: root.url.path, trusted: true))

        XCTAssertEqual(Set(skills.map(\.name)), ["root-skill", "frontend", "codex"])
    }
}

private struct TemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func write(_ relativePath: String, _ content: String) throws {
        let destination = url.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.data(using: .utf8)!.write(to: destination)
    }
}
