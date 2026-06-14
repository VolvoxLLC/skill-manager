import SwiftData
import XCTest
@testable import SkillDeckCore
@testable import SkillDeckPersistence

final class SkillDeckRepositoryTests: XCTestCase {
    func testSavesAndLoadsInstalledSkill() throws {
        let container = try ModelContainer(
            for: InstalledSkillRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SkillDeckRepository(modelContext: ModelContext(container))
        let record = InstalledSkillRecord(
            skillID: "github/example/demo",
            name: "demo",
            sourceLocation: "github/example",
            destinationPath: "/tmp/demo/SKILL.md",
            installedHash: "abc",
            sourceCommit: "123"
        )

        try repository.saveInstalledSkill(record)
        let loaded = try repository.installedSkills()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].skillID, "github/example/demo")
    }
}
