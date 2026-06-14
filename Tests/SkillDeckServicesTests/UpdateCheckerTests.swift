import XCTest
@testable import SkillDeckServices

final class UpdateCheckerTests: XCTestCase {
    func testDetectsAvailableUpdateWhenHashChanges() {
        let result = UpdateChecker.compare(installedHash: "old", upstreamHash: "new")
        XCTAssertEqual(result, .updateAvailable)
    }

    func testReportsUpToDateWhenHashMatches() {
        let result = UpdateChecker.compare(installedHash: "same", upstreamHash: "same")
        XCTAssertEqual(result, .upToDate)
    }
}
