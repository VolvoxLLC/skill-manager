import XCTest
@testable import SkillDeckCore

final class PathSafetyValidatorTests: XCTestCase {
    func testRejectsTraversalOutsideApprovedFolder() throws {
        let approved = URL(fileURLWithPath: "/Users/test/.codex/skills", isDirectory: true)
        let candidate = URL(fileURLWithPath: "/Users/test/.codex/skills/../config.toml")

        XCTAssertThrowsError(try PathSafetyValidator.validateWriteDestination(candidate, inside: approved)) { error in
            XCTAssertEqual(error as? SkillDeckError, .pathTraversalRejected(candidate.path))
        }
    }

    func testAllowsChildInsideApprovedFolder() throws {
        let approved = URL(fileURLWithPath: "/Users/test/.codex/skills", isDirectory: true)
        let candidate = URL(fileURLWithPath: "/Users/test/.codex/skills/frontend-design/SKILL.md")

        let validated = try PathSafetyValidator.validateWriteDestination(candidate, inside: approved)
        XCTAssertEqual(validated.path, "/Users/test/.codex/skills/frontend-design/SKILL.md")
    }
}
