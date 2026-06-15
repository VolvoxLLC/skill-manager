import XCTest
@testable import SkillDeckCore
@testable import SkillDeckServices

final class SkillInstallerTests: XCTestCase {
    func testCopiesSkillMarkdownIntoPreviewDestination() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let destination = root.appendingPathComponent("demo/SKILL.md")
        let preview = InstallPreview(skillName: "demo", destinations: [destination], installMode: .copy, backupRequired: false)
        let installer = SkillInstaller()

        try await installer.install(skillMarkdown: "skill content", preview: preview)

        XCTAssertEqual(try String(contentsOf: destination), "skill content")
    }

    func testThrowsWhenWrittenHashDoesNotMatchExpectedHash() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let destination = root.appendingPathComponent("demo/SKILL.md")
        let preview = InstallPreview(skillName: "demo", destinations: [destination], installMode: .copy, backupRequired: false)
        let installer = SkillInstaller()

        await XCTAssertThrowsErrorAsync(
            try await installer.install(
                skillMarkdown: "skill content",
                preview: preview,
                expectedContentHash: "not-the-written-hash"
            )
        ) { error in
            guard case SkillDeckError.hashMismatchAfterWrite = error else {
                XCTFail("Expected hash mismatch error, got \(error)")
                return
            }
        }
    }
}
