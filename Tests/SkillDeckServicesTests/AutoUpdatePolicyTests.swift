import XCTest
@testable import SkillDeckServices

final class AutoUpdatePolicyTests: XCTestCase {
    func testAllowsTrustedUnmodifiedSourceWithFolderGrant() {
        let decision = AutoUpdatePolicy.evaluate(
            isSourceTrusted: true,
            hasFolderGrant: true,
            hasLocalModifications: false,
            hasStableSourceHash: true,
            backupCanBeCreated: true
        )

        XCTAssertEqual(decision, .allow)
    }

    func testRefusesLocalModifications() {
        let decision = AutoUpdatePolicy.evaluate(
            isSourceTrusted: true,
            hasFolderGrant: true,
            hasLocalModifications: true,
            hasStableSourceHash: true,
            backupCanBeCreated: true
        )

        XCTAssertEqual(decision, .refuse(reason: "Local modifications require manual review."))
    }
}
