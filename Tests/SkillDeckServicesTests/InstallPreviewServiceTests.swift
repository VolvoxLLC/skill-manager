import XCTest
@testable import SkillDeckCore
@testable import SkillDeckServices

final class InstallPreviewServiceTests: XCTestCase {
    func testPreviewFailsWhenFolderGrantIsMissing() async throws {
        let grants = InMemoryFolderGrantStore()
        let service = InstallPreviewService(folderGrants: grants)
        let detail = SkillDetail.fixture()
        let target = AgentTarget(
            kind: .codex,
            displayName: "Codex",
            installPath: URL(fileURLWithPath: "/Users/test/.codex/skills", isDirectory: true),
            scope: .global,
            isEnabled: true
        )

        await XCTAssertThrowsErrorAsync(try await service.previewInstall(skill: detail, targets: [target])) { error in
            XCTAssertEqual(error as? SkillDeckError, .folderGrantMissing("/Users/test/.codex/skills"))
        }
    }
}

private extension SkillDetail {
    static func fixture() -> SkillDetail {
        let summary = SkillSummary(
            id: SkillID("github/example/demo"),
            name: "demo",
            description: "Demo",
            source: SkillSourceReference(kind: .github, location: "github/example", trusted: true),
            installCount: nil,
            tags: [],
            lastUpdated: nil
        )
        return SkillDetail(
            summary: summary,
            readmeMarkdown: "",
            skillMarkdown: "---\nname: demo\ndescription: Demo\n---",
            sourceCommit: "123",
            contentHash: "abc",
            relativePath: "skills/demo/SKILL.md"
        )
    }
}

func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ validation: (Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error", file: file, line: line)
    } catch {
        validation(error)
    }
}
