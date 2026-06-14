import XCTest
@testable import SkillDeckCore
@testable import SkillDeckServices

final class FolderGrantStoreTests: XCTestCase {
    func testMemoryGrantAllowsChildWrite() throws {
        let grants = InMemoryFolderGrantStore()
        let folder = URL(fileURLWithPath: "/Users/test/.codex/skills", isDirectory: true)
        grants.grant(folder)

        let destination = URL(fileURLWithPath: "/Users/test/.codex/skills/demo/SKILL.md")
        XCTAssertTrue(try grants.canWrite(to: destination))
    }

    func testMemoryGrantRejectsSiblingWrite() throws {
        let grants = InMemoryFolderGrantStore()
        grants.grant(URL(fileURLWithPath: "/Users/test/.codex/skills", isDirectory: true))

        XCTAssertFalse(try grants.canWrite(to: URL(fileURLWithPath: "/Users/test/.codex/config.toml")))
    }
}
