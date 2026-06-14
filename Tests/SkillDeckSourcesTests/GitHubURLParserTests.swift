import XCTest
@testable import SkillDeckSources

final class GitHubURLParserTests: XCTestCase {
    func testParsesHTTPSRepositoryURL() throws {
        let repo = try GitHubURLParser.parse("https://github.com/vercel-labs/agent-skills")
        XCTAssertEqual(repo.owner, "vercel-labs")
        XCTAssertEqual(repo.name, "agent-skills")
        XCTAssertNil(repo.ref)
    }

    func testParsesShorthandWithRef() throws {
        let repo = try GitHubURLParser.parse("vercel-labs/agent-skills#main")
        XCTAssertEqual(repo.owner, "vercel-labs")
        XCTAssertEqual(repo.name, "agent-skills")
        XCTAssertEqual(repo.ref, "main")
    }

    func testRejectsNonGitHubURL() {
        XCTAssertThrowsError(try GitHubURLParser.parse("https://example.com/repo"))
    }
}
