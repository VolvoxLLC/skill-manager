import XCTest
@testable import SkillDeck
import SkillDeckCore
import SkillDeckServices
import SkillDeckSources

@MainActor
final class SkillDeckWorkspaceViewModelTests: XCTestCase {
    func testInitialCatalogLoadsTopDownloadedSkillsInDescendingInstallOrder() async {
        let trendingProvider = RecordingTrendingProvider(results: [
            SkillSummary.fixture(name: "middle", installCount: 50),
            SkillSummary.fixture(name: "top", installCount: 200),
            SkillSummary.fixture(name: "low", installCount: 2)
        ])
        let viewModel = SkillDeckWorkspaceViewModel(
            searchProvider: MockSearchProvider(results: []),
            trendingProvider: trendingProvider,
            detailProvider: MockSkillDetailProvider(scans: [:]),
            folderGrants: InMemoryFolderGrantStore(),
            backupRoot: FileManager.default.temporaryDirectory
        )

        await viewModel.loadInitialCatalog()

        XCTAssertEqual(trendingProvider.requests, [25])
        XCTAssertEqual(viewModel.catalogSkills.map(\.name), ["top", "middle", "low"])
    }

    func testSelectingCatalogSkillLoadsDetailsIntoInspectorState() async {
        let summary = SkillSummary.fixture(name: "catalog-demo", installCount: 10)
        let detail = SkillDetail.fixture(name: "catalog-demo", markdown: skillMarkdown(name: "catalog-demo", description: "Catalog demo"))
        let viewModel = SkillDeckWorkspaceViewModel(
            searchProvider: MockSearchProvider(results: []),
            trendingProvider: MockTrendingProvider(results: [summary]),
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

    func testGrantedAgentSkillFoldersAreScannedDirectly() {
        let codexSkills = URL(fileURLWithPath: "/Users/test/.codex/skills", isDirectory: true)
        let codexParent = URL(fileURLWithPath: "/Users/test/.codex", isDirectory: true)
        let claudeSkills = URL(fileURLWithPath: "/Users/test/.claude/skills", isDirectory: true)

        let codexFromSkills = FileSystemInstalledSkillProvider.scanRoots(forGrantedRoot: codexSkills)
        XCTAssertEqual(codexFromSkills.map(\.url.path), [codexSkills.path])
        XCTAssertEqual(codexFromSkills.map(\.targetKind), [.codex])

        let codexFromParent = FileSystemInstalledSkillProvider.scanRoots(forGrantedRoot: codexParent)
        XCTAssertEqual(codexFromParent.map(\.url.path), [codexSkills.path])
        XCTAssertEqual(codexFromParent.map(\.targetKind), [.codex])
        XCTAssertEqual(FileSystemInstalledSkillProvider.scanRoots(forGrantedRoot: claudeSkills).map(\.targetKind), [.claudeCode])
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
        let installedHashBeforeSync = viewModel.installedSkills[0].installedHash
        try "local edit".write(to: installedFile, atomically: true, encoding: .utf8)
        detailProvider.scans = ["owner/repo": [versionTwo]]

        await viewModel.syncInstalledSkills()
        XCTAssertEqual(viewModel.installedSkills[0].installedHash, installedHashBeforeSync)

        await viewModel.checkForUpdates()
        XCTAssertEqual(viewModel.availableUpdates.map(\.skillName), ["demo"])

        await viewModel.updateInstalledSkill(viewModel.installedSkills[0].id)
        XCTAssertEqual(viewModel.pendingConflict?.path, installedFile.path)

        try await viewModel.backupAndOverwriteConflict()
        XCTAssertEqual(try String(contentsOf: installedFile), versionTwo.skillMarkdown)
        XCTAssertEqual(viewModel.selectedSkill?.skillMarkdown, versionTwo.skillMarkdown)
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

    func testExistingUntrackedDestinationRequiresConflictConfirmation() async throws {
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
        let installedFile = destinationRoot.appendingPathComponent("demo/SKILL.md")
        try FileManager.default.createDirectory(at: installedFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "manual local skill".write(to: installedFile, atomically: true, encoding: .utf8)

        try await viewModel.installSelectedSkill()

        XCTAssertEqual(viewModel.pendingConflict?.path, installedFile.path)
        XCTAssertEqual(try String(contentsOf: installedFile), "manual local skill")

        try await viewModel.backupAndOverwriteConflict()
        XCTAssertEqual(try String(contentsOf: installedFile), detail.skillMarkdown)
        XCTAssertNil(viewModel.pendingConflict)
    }

    func testSyncInstalledSkillsPreservesPersistedManagedMetadataAfterRelaunch() async throws {
        let root = try temporaryDirectory()
        let codexRoot = root.appendingPathComponent(".codex/skills", isDirectory: true)
        let skillFile = codexRoot.appendingPathComponent("demo/SKILL.md")
        let installedMarkdown = skillMarkdown(name: "demo", description: "Version one")
        try writeSkill(at: skillFile, name: "demo", description: "Version one")
        let installedHash = ContentHasher.sha256Hex(installedMarkdown)
        let managedStore = InMemoryManagedInstallStore(records: [
            ManagedInstalledSkillRecord(
                skillID: SkillID("owner/repo/demo"),
                name: "demo",
                description: "Version one",
                sourceKind: .github,
                sourceLocation: "owner/repo",
                targetDisplayName: "Managed",
                destination: skillFile,
                installedHash: installedHash,
                sourceCommit: "abc123"
            )
        ])
        let upstream = SkillDetail.fixture(name: "demo", markdown: skillMarkdown(name: "demo", description: "Version two"))
        let viewModel = SkillDeckWorkspaceViewModel(
            searchProvider: MockSearchProvider(results: []),
            detailProvider: MockSkillDetailProvider(scans: ["owner/repo": [upstream]]),
            folderGrants: InMemoryFolderGrantStore(),
            backupRoot: try temporaryDirectory(),
            installedSkillProvider: FileSystemInstalledSkillProvider(roots: [
                InstalledSkillScanRoot(url: codexRoot, targetKind: .codex, displayName: "Codex")
            ]),
            managedInstallStore: managedStore
        )

        await viewModel.syncInstalledSkills()

        XCTAssertEqual(viewModel.installedSkills.count, 1)
        let installed = try XCTUnwrap(viewModel.installedSkills.first)
        XCTAssertEqual(installed.sourceKind, .github)
        XCTAssertEqual(installed.sourceLocation, "owner/repo")
        XCTAssertEqual(installed.installedHash, installedHash)
        XCTAssertEqual(installed.sourceCommit, "abc123")

        XCTAssertEqual(viewModel.availableSkills.count, 1)
        let available = try XCTUnwrap(viewModel.availableSkills.first)
        XCTAssertEqual(available.summary.source.kind, .github)

        await viewModel.checkForUpdates()
        XCTAssertEqual(viewModel.availableUpdates.map(\.skillName), ["demo"])
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
        let installed = try XCTUnwrap(viewModel.installedSkills.first)
        await viewModel.selectInstalledSkill(installed.id)
        XCTAssertEqual(viewModel.availableSkills.map(\.summary.name), ["repo-helper"])

        try FileManager.default.removeItem(at: skillFile.deletingLastPathComponent())
        await viewModel.syncInstalledSkills()

        XCTAssertTrue(viewModel.installedSkills.isEmpty)
        XCTAssertFalse(viewModel.availableSkills.contains { $0.summary.name == "repo-helper" })
        XCTAssertNil(viewModel.selectedSkill)
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


    func testSyncInstalledSkillsClearsLocalRowsWhenNoRootsRemainAccessible() async throws {
        let root = try temporaryDirectory()
        let agentsRoot = root.appendingPathComponent(".agents/skills", isDirectory: true)
        let skillFile = agentsRoot.appendingPathComponent("repo-helper/SKILL.md")
        let markdown = skillMarkdown(name: "repo-helper", description: "Repo helper")
        let provider = MutableInstalledSkillProvider(result: InstalledSkillScanResult(
            skills: [ScannedInstalledSkill(
                name: "repo-helper",
                description: "Repo helper",
                targetKind: .codex,
                targetDisplayName: "Codex",
                rootURL: agentsRoot,
                destination: skillFile,
                skillMarkdown: markdown,
                installedHash: ContentHasher.sha256Hex(markdown)
            )],
            scannedRootURLs: [agentsRoot]
        ))
        let viewModel = SkillDeckWorkspaceViewModel(
            searchProvider: MockSearchProvider(results: []),
            detailProvider: MockSkillDetailProvider(scans: [:]),
            folderGrants: InMemoryFolderGrantStore(),
            backupRoot: try temporaryDirectory(),
            installedSkillProvider: provider
        )

        await viewModel.syncInstalledSkills()
        XCTAssertEqual(viewModel.installedSkills.map(\.name), ["repo-helper"])

        provider.result = InstalledSkillScanResult(skills: [], scannedRootURLs: [])
        await viewModel.syncInstalledSkills()

        XCTAssertTrue(viewModel.installedSkills.isEmpty)
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

private final class RecordingTrendingProvider: SkillTrendingProviding, @unchecked Sendable {
    private(set) var requests: [Int] = []
    private let results: [SkillSummary]

    init(results: [SkillSummary]) {
        self.results = results
    }

    func trending(limit: Int) async throws -> [SkillSummary] {
        requests.append(limit)
        return results
    }
}

private struct MockTrendingProvider: SkillTrendingProviding {
    let results: [SkillSummary]

    func trending(limit: Int) async throws -> [SkillSummary] {
        Array(results.prefix(limit))
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

private final class MutableInstalledSkillProvider: InstalledSkillProviding, @unchecked Sendable {
    var result: InstalledSkillScanResult

    init(result: InstalledSkillScanResult) {
        self.result = result
    }

    func scanInstalledSkills() async throws -> InstalledSkillScanResult {
        result
    }
}

private final class InMemoryManagedInstallStore: ManagedInstalledSkillPersisting {
    var records: [ManagedInstalledSkillRecord]

    init(records: [ManagedInstalledSkillRecord] = []) {
        self.records = records
    }

    func loadRecords() -> [ManagedInstalledSkillRecord] {
        records
    }

    func save(_ record: ManagedInstalledSkillRecord) {
        let destination = record.destination.standardizedFileURL
        records.removeAll { $0.destination.standardizedFileURL == destination }
        records.append(record)
    }

    func removeRecords(for destinations: Set<URL>) {
        let standardizedDestinations = Set(destinations.map(\.standardizedFileURL))
        records.removeAll { standardizedDestinations.contains($0.destination.standardizedFileURL) }
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
