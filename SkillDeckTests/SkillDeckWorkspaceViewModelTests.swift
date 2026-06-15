import XCTest
@testable import SkillDeck
import SkillDeckCore
import SkillDeckServices
import SkillDeckSources

@MainActor
final class SkillDeckWorkspaceViewModelTests: XCTestCase {
    func testInitialCatalogLoadsTopDownloadedSkillsInDescendingInstallOrder() async {
        let searchProvider = RecordingSearchProvider(results: [
            SkillSummary.fixture(name: "middle", installCount: 50),
            SkillSummary.fixture(name: "top", installCount: 200),
            SkillSummary.fixture(name: "low", installCount: 2)
        ])
        let viewModel = SkillDeckWorkspaceViewModel(
            searchProvider: searchProvider,
            detailProvider: MockSkillDetailProvider(scans: [:]),
            folderGrants: InMemoryFolderGrantStore(),
            backupRoot: FileManager.default.temporaryDirectory
        )

        await viewModel.loadInitialCatalog()

        XCTAssertEqual(searchProvider.requests, [SearchRequest(query: "skill", limit: 25)])
        XCTAssertEqual(viewModel.catalogSkills.map(\.name), ["top", "middle", "low"])
    }

    func testSelectingCatalogSkillLoadsDetailsIntoInspectorState() async {
        let summary = SkillSummary.fixture(name: "catalog-demo", installCount: 10)
        let detail = SkillDetail.fixture(name: "catalog-demo", markdown: skillMarkdown(name: "catalog-demo", description: "Catalog demo"))
        let viewModel = SkillDeckWorkspaceViewModel(
            searchProvider: MockSearchProvider(results: [summary]),
            detailProvider: MockSkillDetailProvider(scans: ["owner/repo": [detail]]),
            folderGrants: InMemoryFolderGrantStore(),
            backupRoot: FileManager.default.temporaryDirectory
        )

        await viewModel.loadInitialCatalog()
        await viewModel.selectSkill(summary.id)

        XCTAssertEqual(viewModel.selectedSkill?.summary.name, "catalog-demo")
        XCTAssertEqual(viewModel.selectedSkill?.skillMarkdown, detail.skillMarkdown)
    }

    func testSyncInstalledSkillsLoadsLocalAgentFolders() async throws {
        let root = try temporaryDirectory()
        let agentsRoot = root.appendingPathComponent(".agents/skills", isDirectory: true)
        try writeSkill(at: agentsRoot.appendingPathComponent("repo-helper/SKILL.md"), name: "repo-helper", description: "Repo helper")
        let installedProvider = FileSystemInstalledSkillProvider(roots: [
            InstalledSkillScanRoot(url: agentsRoot, targetKind: .codex, displayName: "Codex")
        ])
        let viewModel = SkillDeckWorkspaceViewModel(
            searchProvider: MockSearchProvider(results: []),
            detailProvider: MockSkillDetailProvider(scans: [:]),
            folderGrants: InMemoryFolderGrantStore(),
            backupRoot: try temporaryDirectory(),
            installedSkillProvider: installedProvider
        )

        await viewModel.syncInstalledSkills()

        XCTAssertEqual(viewModel.installedSkills.map(\.name), ["repo-helper"])
        XCTAssertEqual(viewModel.installedSkills[0].sourceLocation, agentsRoot.path)
    }

    func testSelectingSyncedInstalledSkillLoadsDetailsIntoInspectorState() async throws {
        let root = try temporaryDirectory()
        let agentsRoot = root.appendingPathComponent(".agents/skills", isDirectory: true)
        try writeSkill(at: agentsRoot.appendingPathComponent("repo-helper/SKILL.md"), name: "repo-helper", description: "Repo helper")
        let viewModel = SkillDeckWorkspaceViewModel(
            searchProvider: MockSearchProvider(results: []),
            detailProvider: MockSkillDetailProvider(scans: [:]),
            folderGrants: InMemoryFolderGrantStore(),
            backupRoot: try temporaryDirectory(),
            installedSkillProvider: FileSystemInstalledSkillProvider(roots: [
                InstalledSkillScanRoot(url: agentsRoot, targetKind: .codex, displayName: "Codex")
            ])
        )

        await viewModel.syncInstalledSkills()
        await viewModel.selectInstalledSkill(viewModel.installedSkills[0].id)

        XCTAssertEqual(viewModel.selectedSkill?.summary.name, "repo-helper")
        XCTAssertEqual(viewModel.selectedSkill?.summary.source.kind, .local)
    }

    func testAddsGitHubSourceSelectsSkillAndInstallsIntoGrantedFolder() async throws {
        let destinationRoot = try temporaryDirectory()
        let detail = SkillDetail.fixture(name: "demo", markdown: skillMarkdown(name: "demo", description: "Demo"))
        let viewModel = SkillDeckWorkspaceViewModel(
            searchProvider: MockSearchProvider(results: []),
            detailProvider: MockSkillDetailProvider(scans: ["owner/repo": [detail]]),
            folderGrants: InMemoryFolderGrantStore(),
            backupRoot: try temporaryDirectory()
        )

        await viewModel.addGitHubSource("owner/repo")
        await viewModel.selectSkill(detail.summary.id)
        viewModel.grantInstallFolder(destinationRoot, kind: .codex, displayName: "Codex")
        await viewModel.previewSelectedSkillForInstall()
        try await viewModel.installSelectedSkill()

        let installedFile = destinationRoot.appendingPathComponent("demo/SKILL.md")
        XCTAssertEqual(try String(contentsOf: installedFile), detail.skillMarkdown)
        XCTAssertEqual(viewModel.installedSkills.map(\.name), ["demo"])
        XCTAssertTrue(viewModel.logs.contains { $0.message.contains("Installed demo") })
    }

    func testUpdateStopsOnLocalModificationThenBacksUpOverwritesAndRestores() async throws {
        let destinationRoot = try temporaryDirectory()
        let backupRoot = try temporaryDirectory()
        let versionOne = SkillDetail.fixture(name: "demo", markdown: skillMarkdown(name: "demo", description: "Version one"))
        let versionTwo = SkillDetail.fixture(name: "demo", markdown: skillMarkdown(name: "demo", description: "Version two"))
        let detailProvider = MutableSkillDetailProvider(scans: ["owner/repo": [versionOne]])
        let viewModel = SkillDeckWorkspaceViewModel(
            searchProvider: MockSearchProvider(results: []),
            detailProvider: detailProvider,
            folderGrants: InMemoryFolderGrantStore(),
            backupRoot: backupRoot,
            installedSkillProvider: FileSystemInstalledSkillProvider(roots: [
                InstalledSkillScanRoot(url: destinationRoot, targetKind: .codex, displayName: "Codex")
            ])
        )

        await viewModel.addGitHubSource("owner/repo")
        await viewModel.selectSkill(versionOne.summary.id)
        viewModel.grantInstallFolder(destinationRoot, kind: .codex, displayName: "Codex")
        await viewModel.previewSelectedSkillForInstall()
        try await viewModel.installSelectedSkill()

        let installedFile = destinationRoot.appendingPathComponent("demo/SKILL.md")
        try "local edit".write(to: installedFile, atomically: true, encoding: .utf8)
        detailProvider.scans = ["owner/repo": [versionTwo]]

        await viewModel.checkForUpdates()
        XCTAssertEqual(viewModel.availableUpdates.map(\.skillName), ["demo"])

        await viewModel.updateInstalledSkill(viewModel.installedSkills[0].id)
        XCTAssertEqual(viewModel.pendingConflict?.path, installedFile.path)

        try await viewModel.backupAndOverwriteConflict()
        XCTAssertEqual(try String(contentsOf: installedFile), versionTwo.skillMarkdown)
        XCTAssertNotNil(viewModel.installedSkills[0].latestBackup)
        let installedID = viewModel.installedSkills[0].id

        await viewModel.syncInstalledSkills()
        XCTAssertEqual(viewModel.installedSkills[0].id, installedID)
        XCTAssertEqual(viewModel.installedSkills[0].sourceKind, .github)
        XCTAssertEqual(viewModel.installedSkills[0].sourceLocation, "owner/repo")
        XCTAssertNotNil(viewModel.installedSkills[0].latestBackup)

        try viewModel.restoreLatestBackup(for: viewModel.installedSkills[0].id)
        XCTAssertEqual(try String(contentsOf: installedFile), "local edit")
    }

    func testSyncInstalledSkillsRemovesDeletedFilesFromTrackedState() async throws {
        let root = try temporaryDirectory()
        let agentsRoot = root.appendingPathComponent(".agents/skills", isDirectory: true)
        let skillFile = agentsRoot.appendingPathComponent("repo-helper/SKILL.md")
        try writeSkill(at: skillFile, name: "repo-helper", description: "Repo helper")
        let viewModel = SkillDeckWorkspaceViewModel(
            searchProvider: MockSearchProvider(results: []),
            detailProvider: MockSkillDetailProvider(scans: [:]),
            folderGrants: InMemoryFolderGrantStore(),
            backupRoot: try temporaryDirectory(),
            installedSkillProvider: FileSystemInstalledSkillProvider(roots: [
                InstalledSkillScanRoot(url: agentsRoot, targetKind: .codex, displayName: "Codex")
            ])
        )

        await viewModel.syncInstalledSkills()
        XCTAssertEqual(viewModel.installedSkills.map(\.name), ["repo-helper"])

        try FileManager.default.removeItem(at: skillFile.deletingLastPathComponent())
        await viewModel.syncInstalledSkills()

        XCTAssertTrue(viewModel.installedSkills.isEmpty)
    }

    func testCheckForUpdatesSkipsLocalOnlyInstalledSkills() async throws {
        let root = try temporaryDirectory()
        let agentsRoot = root.appendingPathComponent(".agents/skills", isDirectory: true)
        try writeSkill(at: agentsRoot.appendingPathComponent("repo-helper/SKILL.md"), name: "repo-helper", description: "Repo helper")
        let viewModel = SkillDeckWorkspaceViewModel(
            searchProvider: MockSearchProvider(results: []),
            detailProvider: FailingSkillDetailProvider(),
            folderGrants: InMemoryFolderGrantStore(),
            backupRoot: try temporaryDirectory(),
            installedSkillProvider: FileSystemInstalledSkillProvider(roots: [
                InstalledSkillScanRoot(url: agentsRoot, targetKind: .codex, displayName: "Codex")
            ])
        )

        await viewModel.syncInstalledSkills()
        await viewModel.checkForUpdates()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.availableUpdates.isEmpty)
    }
}

private struct SearchRequest: Equatable {
    let query: String
    let limit: Int
}

private final class RecordingSearchProvider: SkillSearchProviding, @unchecked Sendable {
    private(set) var requests: [SearchRequest] = []
    private let results: [SkillSummary]

    init(results: [SkillSummary]) {
        self.results = results
    }

    func search(query: String, limit: Int) async throws -> [SkillSummary] {
        requests.append(SearchRequest(query: query, limit: limit))
        return results
    }
}

final class MutableSkillDetailProvider: SkillDetailProviding, @unchecked Sendable {
    var scans: [String: [SkillDetail]]

    init(scans: [String: [SkillDetail]]) {
        self.scans = scans
    }

    func scan(source: String) async throws -> [SkillDetail] {
        scans[source] ?? []
    }
}

private extension SkillSummary {
    static func fixture(name: String, installCount: Int) -> SkillSummary {
        SkillSummary(
            id: SkillID("source/\(name)"),
            name: name,
            description: "\(name) description",
            source: SkillSourceReference(kind: .skillsSh, location: "owner/repo", trusted: true),
            installCount: installCount,
            tags: [],
            lastUpdated: nil
        )
    }
}

private struct MockSearchProvider: SkillSearchProviding {
    let results: [SkillSummary]

    func search(query: String, limit: Int) async throws -> [SkillSummary] {
        results
    }
}

private struct MockSkillDetailProvider: SkillDetailProviding {
    let scans: [String: [SkillDetail]]

    func scan(source: String) async throws -> [SkillDetail] {
        scans[source] ?? []
    }
}

private struct FailingSkillDetailProvider: SkillDetailProviding {
    func scan(source: String) async throws -> [SkillDetail] {
        throw SkillDeckError.sourceUnavailable("Unexpected scan for \(source)")
    }
}

private extension SkillDetail {
    static func fixture(name: String, markdown: String) -> SkillDetail {
        let summary = SkillSummary(
            id: SkillID("owner/repo/\(name)"),
            name: name,
            description: name,
            source: SkillSourceReference(kind: .github, location: "owner/repo", trusted: true),
            installCount: nil,
            tags: [],
            lastUpdated: nil
        )

        return SkillDetail(
            summary: summary,
            readmeMarkdown: "# \(name)",
            skillMarkdown: markdown,
            sourceCommit: "abc123",
            contentHash: ContentHasher.sha256Hex(markdown),
            relativePath: "skills/\(name)/SKILL.md"
        )
    }
}

private func skillMarkdown(name: String, description: String) -> String {
    """
    ---
    name: \(name)
    description: \(description)
    ---
    """
}

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func writeSkill(at url: URL, name: String, description: String) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try skillMarkdown(name: name, description: description).write(to: url, atomically: true, encoding: .utf8)
}
