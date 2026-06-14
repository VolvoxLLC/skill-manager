import XCTest
@testable import SkillDeckCore
@testable import SkillDeckSources

final class SkillManifestParserTests: XCTestCase {
    func testParsesNameAndDescriptionFromFrontmatter() throws {
        let markdown = """
        ---
        name: swiftui-helper
        description: Helps build SwiftUI views
        ---

        # SwiftUI Helper
        """

        let manifest = try SkillManifestParser.parse(markdown)

        XCTAssertEqual(manifest.name, "swiftui-helper")
        XCTAssertEqual(manifest.description, "Helps build SwiftUI views")
    }

    func testRejectsMissingDescription() {
        let markdown = """
        ---
        name: broken
        ---

        # Broken
        """

        XCTAssertThrowsError(try SkillManifestParser.parse(markdown)) { error in
            XCTAssertEqual(error as? SkillDeckError, .invalidSkillStructure("SKILL.md must define string name and description frontmatter."))
        }
    }
}
