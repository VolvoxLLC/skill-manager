import XCTest
@testable import SkillDeckCore

final class CoreModelTests: XCTestCase {
    func testSkillIdentityCombinesSourceAndName() {
        let skill = SkillSummary(
            id: SkillID("github/awesome-copilot/typescript-mcp-server-generator"),
            name: "typescript-mcp-server-generator",
            description: "Generates MCP servers",
            source: SkillSourceReference(kind: .github, location: "github/awesome-copilot", trusted: true),
            installCount: 10_611,
            tags: ["typescript"],
            lastUpdated: nil
        )

        XCTAssertEqual(skill.id.rawValue, "github/awesome-copilot/typescript-mcp-server-generator")
        XCTAssertEqual(skill.source.kind, .github)
        XCTAssertTrue(skill.source.trusted)
    }

    func testHasherProducesStableSHA256() throws {
        let digest = ContentHasher.sha256Hex(Data("SkillDeck".utf8))
        XCTAssertEqual(digest.count, 64)
        XCTAssertEqual(digest, ContentHasher.sha256Hex(Data("SkillDeck".utf8)))
    }
}
