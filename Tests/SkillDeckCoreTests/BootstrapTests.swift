import XCTest
@testable import SkillDeckCore

final class BootstrapTests: XCTestCase {
    func testPackageExposesVersionedAppIdentity() {
        XCTAssertEqual(AppIdentity.name, "SkillDeck")
        XCTAssertEqual(AppIdentity.minimumSupportedMacOSMajorVersion, 14)
    }
}
