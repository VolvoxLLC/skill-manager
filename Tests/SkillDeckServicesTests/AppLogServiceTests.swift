import XCTest
@testable import SkillDeckServices

final class AppLogServiceTests: XCTestCase {
    func testMemoryLoggerStoresRedactedPathMessage() async {
        let logger = InMemoryAppLogService()
        await logger.info(category: "FileSystem", message: "Wrote /Users/bill/.codex/skills/demo/SKILL.md")

        let entries = await logger.entries()
        XCTAssertEqual(entries[0].message, "Wrote <path>/demo/SKILL.md")
    }
}
