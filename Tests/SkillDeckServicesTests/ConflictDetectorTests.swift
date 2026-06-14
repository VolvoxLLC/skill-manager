import XCTest
@testable import SkillDeckCore
@testable import SkillDeckServices

final class ConflictDetectorTests: XCTestCase {
    func testReportsNoConflictWhenHashMatchesLastInstall() {
        let result = ConflictDetector.detect(currentHash: "abc", lastInstalledHash: "abc", destinationPath: "/tmp/SKILL.md")
        XCTAssertEqual(result, .none)
    }

    func testReportsLocalModificationWhenHashDiffers() {
        let result = ConflictDetector.detect(currentHash: "changed", lastInstalledHash: "abc", destinationPath: "/tmp/SKILL.md")
        XCTAssertEqual(result, .localModification(path: "/tmp/SKILL.md"))
    }
}
