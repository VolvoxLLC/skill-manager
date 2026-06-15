import Combine
import Foundation
import SkillDeckCore
import SkillDeckServices
import SkillDeckSources

protocol SkillDetailProviding: Sendable {
    func scan(source: String) async throws -> [SkillDetail]
}

extension GitHubSkillSourceProvider: SkillDetailProviding {}

protocol FolderGrantManaging: FolderGrantChecking {
    func grant(_ folder: URL)
}

extension InMemoryFolderGrantStore: FolderGrantManaging {}

protocol InstalledSkillProviding: Sendable {
    func scanInstalledSkills() async throws -> [ScannedInstalledSkill]
}

struct FileSystemInstalledSkillProvider: InstalledSkillProviding {
    private let scanner: SkillDeckServices.InstalledSkillScanner
    private let roots: [SkillDeckServices.InstalledSkillScanRoot]

    init(
        scanner: SkillDeckServices.InstalledSkillScanner = SkillDeckServices.InstalledSkillScanner(),
        roots: [SkillDeckServices.InstalledSkillScanRoot] = SkillDeckServices.InstalledSkillScanner.defaultRoots()
    ) {
        self.scanner = scanner
        self.roots = roots
    }

    func scanInstalledSkills() async throws -> [ScannedInstalledSkill] {
        try scanner.scan(roots: roots)
    }
}

struct InstalledSkillViewState: Identifiable, Equatable {
    let id: UUID
    var skillID: SkillID
    var name: String
    var description: String
    var sourceLocation: String
    var targetDisplayName: String
    var destination: URL
    var installedHash: String
    var sourceCommit: String?
    var latestBackup: SkillBackupViewState?
}

struct SkillBackupViewState: Equatable {
    let url: URL
    let destination: URL
    let oldHash: String
}

struct SkillUpdateViewState: Identifiable, Equatable {
    let id = UUID()
    let installedSkillID: UUID
    let skillName: String
    let upstreamDetail: SkillDetail
    let installedHash: String
    let upstreamHash: String
}

struct SkillConflictViewState: Equatable {
    let path: String
    let installedSkillID: UUID
    let upstreamDetail: SkillDetail
}

@MainActor
final class SkillDeckWorkspaceViewModel: ObservableObject {
    @Published private(set) var catalogSkills: [SkillSummary] = []
    @Published private(set) var searchResults: [SkillSummary] = []
    @Published private(set) var availableSkills: [SkillDetail] = []
    @Published private(set) var installedSkills: [InstalledSkillViewState] = []
    @Published private(set) var availableUpdates: [SkillUpdateViewState] = []
    @Published private(set) var logs: [AppLogEntry] = []
    @Published private(set) var installTargets: [AgentTarget] = []
    @Published private(set) var selectedSkill: SkillDetail?
    @Published var pendingInstallPreview: InstallPreview?
    @Published var pendingConflict: SkillConflictViewState?
    @Published var errorMessage: String?

    private let searchProvider: SkillSearchProviding
    private let detailProvider: SkillDetailProviding
    private let folderGrants: FolderGrantManaging
    private let backupManager: BackupManager
    private let installer: SkillInstaller
    private let logger: InMemoryAppLogService
    private let installedSkillProvider: InstalledSkillProviding
    private var hasBootstrapped = false

    init(
        searchProvider: SkillSearchProviding = SkillsShSearchProvider(),
        detailProvider: SkillDetailProviding = GitHubSkillSourceProvider(),
        folderGrants: FolderGrantManaging = InMemoryFolderGrantStore(),
        backupRoot: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("SkillDeck/Backups", isDirectory: true),
        installer: SkillInstaller = SkillInstaller(),
        logger: InMemoryAppLogService = InMemoryAppLogService(),
        installedSkillProvider: InstalledSkillProviding = FileSystemInstalledSkillProvider()
    ) {
        self.searchProvider = searchProvider
        self.detailProvider = detailProvider
        self.folderGrants = folderGrants
        self.backupManager = BackupManager(backupRoot: backupRoot)
        self.installer = installer
        self.logger = logger
        self.installedSkillProvider = installedSkillProvider
    }

    func bootstrap() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        await loadInitialCatalog()
        await syncInstalledSkills()
    }

    func loadInitialCatalog() async {
        do {
            let results = try await searchProvider.search(query: "skill", limit: 25)
            catalogSkills = sortedByInstallCount(results)
            searchResults = catalogSkills
            await appendLog(category: "Discovery", message: "Loaded \(catalogSkills.count) top skills")
        } catch {
            setError(error)
        }
    }

    func syncInstalledSkills() async {
        do {
            let scannedSkills = try await installedSkillProvider.scanInstalledSkills()
            for scannedSkill in scannedSkills {
                mergeAvailableSkills([detail(from: scannedSkill)])
                upsertInstalledSkill(scannedSkill)
            }
            await appendLog(category: "Install", message: "Synced \(scannedSkills.count) installed skills")
        } catch {
            setError(error)
        }
    }

    func search(_ query: String) async {
        do {
            searchResults = sortedByInstallCount(try await searchProvider.search(query: query, limit: 25))
            await appendLog(category: "Discovery", message: "Search returned \(searchResults.count) skills")
        } catch {
            setError(error)
        }
    }

    func addGitHubSource(_ source: String) async {
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty else {
            errorMessage = "Enter a GitHub owner/repo source."
            return
        }

        do {
            let details = try await detailProvider.scan(source: trimmedSource)
            mergeAvailableSkills(details)
            await appendLog(category: "GitHub", message: "Added source \(trimmedSource) with \(details.count) skills")
        } catch {
            setError(error)
        }
    }

    func selectSkill(_ id: SkillID) async {
        if let detail = availableSkills.first(where: { $0.summary.id == id }) {
            selectedSkill = detail
            await appendLog(category: "Skills", message: "Selected \(detail.summary.name)")
            return
        }

        if let summary = searchResults.first(where: { $0.id == id }) {
            await loadDetailsForSearchResult(summary)
            return
        }

        errorMessage = "Skill details are unavailable."
    }

    func grantInstallFolder(_ folder: URL, kind: AgentTargetKind, displayName: String, scope: InstallScope = .global) {
        folderGrants.grant(folder)
        installTargets.removeAll { $0.kind == kind && $0.installPath == folder }
        installTargets.append(
            AgentTarget(
                kind: kind,
                displayName: displayName,
                installPath: folder,
                scope: scope,
                isEnabled: true
            )
        )
    }

    func previewSelectedSkillForInstall() async {
        guard let selectedSkill else {
            errorMessage = "Select a skill before installing."
            return
        }
        guard !installTargets.isEmpty else {
            errorMessage = "Grant an install folder before installing."
            return
        }

        do {
            let service = InstallPreviewService(folderGrants: folderGrants)
            pendingInstallPreview = try await service.previewInstall(skill: selectedSkill, targets: installTargets)
            await appendLog(category: "Install", message: "Previewed install for \(selectedSkill.summary.name)")
        } catch {
            setError(error)
        }
    }

    func installSelectedSkill() async throws {
        guard let selectedSkill else {
            errorMessage = "Select a skill before installing."
            return
        }
        guard let preview = pendingInstallPreview else {
            await previewSelectedSkillForInstall()
            if pendingConflict != nil { return }
            guard let pendingInstallPreview else { return }
            try await install(skill: selectedSkill, preview: pendingInstallPreview)
            return
        }

        try await install(skill: selectedSkill, preview: preview)
    }

    func checkForUpdates() async {
        var updates: [SkillUpdateViewState] = []

        for installedSkill in installedSkills {
            do {
                let upstreamDetails = try await detailProvider.scan(source: installedSkill.sourceLocation)
                guard let upstream = upstreamDetails.first(where: { $0.summary.name == installedSkill.name }) else {
                    continue
                }
                guard UpdateChecker.compare(installedHash: installedSkill.installedHash, upstreamHash: upstream.contentHash) == .updateAvailable else {
                    continue
                }
                updates.append(
                    SkillUpdateViewState(
                        installedSkillID: installedSkill.id,
                        skillName: installedSkill.name,
                        upstreamDetail: upstream,
                        installedHash: installedSkill.installedHash,
                        upstreamHash: upstream.contentHash
                    )
                )
            } catch {
                setError(error)
            }
        }

        availableUpdates = updates
        await appendLog(category: "Update", message: "Found \(updates.count) available updates")
    }

    func updateInstalledSkill(_ installedSkillID: UUID) async {
        guard let update = availableUpdates.first(where: { $0.installedSkillID == installedSkillID }),
              let installedSkill = installedSkills.first(where: { $0.id == installedSkillID }) else {
            errorMessage = "No update is available for that skill."
            return
        }

        do {
            if try hasLocalModification(installedSkill) {
                pendingConflict = SkillConflictViewState(
                    path: installedSkill.destination.path,
                    installedSkillID: installedSkill.id,
                    upstreamDetail: update.upstreamDetail
                )
                await appendLog(category: "Install", message: "Conflict detected for \(installedSkill.name)")
                return
            }

            try await overwriteInstalledSkill(installedSkill, with: update.upstreamDetail)
        } catch {
            setError(error)
        }
    }

    func backupAndOverwriteConflict() async throws {
        guard let pendingConflict,
              let installedSkill = installedSkills.first(where: { $0.id == pendingConflict.installedSkillID }) else {
            return
        }

        try await overwriteInstalledSkill(installedSkill, with: pendingConflict.upstreamDetail)
        self.pendingConflict = nil
    }

    func keepLocalConflict() async {
        guard let pendingConflict else { return }
        self.pendingConflict = nil
        await appendLog(category: "Install", message: "Kept local changes at \(pendingConflict.path)")
    }

    func restoreLatestBackup(for installedSkillID: UUID) throws {
        guard let index = installedSkills.firstIndex(where: { $0.id == installedSkillID }),
              let latestBackup = installedSkills[index].latestBackup else {
            errorMessage = "No backup is available for that skill."
            return
        }

        try installer.restoreBackup(from: latestBackup.url, to: latestBackup.destination)
        installedSkills[index].installedHash = latestBackup.oldHash
    }

    func selectInstalledSkill(_ installedSkillID: UUID) async {
        guard let installedSkill = installedSkills.first(where: { $0.id == installedSkillID }) else {
            errorMessage = "Installed skill is unavailable."
            return
        }

        if let detail = availableSkills.first(where: { $0.summary.id == installedSkill.skillID }) {
            selectedSkill = detail
            await appendLog(category: "Skills", message: "Selected \(detail.summary.name)")
            return
        }

        errorMessage = "Installed skill details are unavailable."
    }

    private func loadDetailsForSearchResult(_ summary: SkillSummary) async {
        do {
            let details = try await detailProvider.scan(source: summary.source.location)
            mergeAvailableSkills(details)
            selectedSkill = availableSkills.first(where: { $0.summary.name == summary.name || $0.summary.id == summary.id })
            await appendLog(category: "Skills", message: "Loaded details for \(summary.name)")
        } catch {
            setError(error)
        }
    }

    private func install(skill: SkillDetail, preview: InstallPreview) async throws {
        if let conflict = try firstConflict(in: preview) {
            pendingInstallPreview = nil
            pendingConflict = SkillConflictViewState(
                path: conflict.destination.path,
                installedSkillID: conflict.installedSkill.id,
                upstreamDetail: skill
            )
            await appendLog(category: "Install", message: "Conflict detected for \(conflict.installedSkill.name)")
            return
        }

        let backups = try backupExistingFiles(in: preview, skillID: skill.summary.id)
        try await installer.install(
            skillMarkdown: skill.skillMarkdown,
            preview: preview,
            expectedContentHash: skill.contentHash
        )

        for destination in preview.destinations {
            let backup = backups[destination]
            upsertInstalledSkill(
                skill: skill,
                destination: destination,
                installedHash: skill.contentHash,
                latestBackup: backup
            )
        }

        pendingInstallPreview = nil
        await appendLog(category: "Install", message: "Installed \(skill.summary.name)")
    }

    private func overwriteInstalledSkill(_ installedSkill: InstalledSkillViewState, with upstream: SkillDetail) async throws {
        let preview = InstallPreview(
            skillName: upstream.summary.name,
            destinations: [installedSkill.destination],
            installMode: .copy,
            backupRequired: true
        )
        let backup = try backupExistingFiles(in: preview, skillID: upstream.summary.id)[installedSkill.destination]
        try await installer.install(
            skillMarkdown: upstream.skillMarkdown,
            preview: preview,
            expectedContentHash: upstream.contentHash
        )
        upsertInstalledSkill(
            skill: upstream,
            destination: installedSkill.destination,
            installedHash: upstream.contentHash,
            latestBackup: backup
        )
        availableUpdates.removeAll { $0.installedSkillID == installedSkill.id }
        await appendLog(category: "Update", message: "Updated \(upstream.summary.name)")
    }

    private func firstConflict(in preview: InstallPreview) throws -> (installedSkill: InstalledSkillViewState, destination: URL)? {
        for destination in preview.destinations {
            guard FileManager.default.fileExists(atPath: destination.path),
                  let installedSkill = installedSkills.first(where: { $0.destination == destination }) else {
                continue
            }

            if try hasLocalModification(installedSkill) {
                return (installedSkill, destination)
            }
        }
        return nil
    }

    private func hasLocalModification(_ installedSkill: InstalledSkillViewState) throws -> Bool {
        guard FileManager.default.fileExists(atPath: installedSkill.destination.path) else {
            return false
        }

        let currentHash = ContentHasher.sha256Hex(try Data(contentsOf: installedSkill.destination))
        return ConflictDetector.detect(
            currentHash: currentHash,
            lastInstalledHash: installedSkill.installedHash,
            destinationPath: installedSkill.destination.path
        ) != .none
    }

    private func backupExistingFiles(in preview: InstallPreview, skillID: SkillID) throws -> [URL: SkillBackupViewState] {
        var backups: [URL: SkillBackupViewState] = [:]

        for destination in preview.destinations where FileManager.default.fileExists(atPath: destination.path) {
            let oldHash = ContentHasher.sha256Hex(try Data(contentsOf: destination))
            let backupURL = try backupManager.backupFile(at: destination, skillID: skillID.rawValue)
            backups[destination] = SkillBackupViewState(url: backupURL, destination: destination, oldHash: oldHash)
        }

        return backups
    }

    private func upsertInstalledSkill(
        skill: SkillDetail,
        destination: URL,
        installedHash: String,
        latestBackup: SkillBackupViewState?
    ) {
        if let index = installedSkills.firstIndex(where: { $0.destination == destination }) {
            installedSkills[index].skillID = skill.summary.id
            installedSkills[index].name = skill.summary.name
            installedSkills[index].description = skill.summary.description
            installedSkills[index].sourceLocation = skill.summary.source.location
            installedSkills[index].targetDisplayName = "Managed"
            installedSkills[index].installedHash = installedHash
            installedSkills[index].sourceCommit = skill.sourceCommit
            installedSkills[index].latestBackup = latestBackup ?? installedSkills[index].latestBackup
            return
        }

        installedSkills.append(
            InstalledSkillViewState(
                id: UUID(),
                skillID: skill.summary.id,
                name: skill.summary.name,
                description: skill.summary.description,
                sourceLocation: skill.summary.source.location,
                targetDisplayName: "Managed",
                destination: destination,
                installedHash: installedHash,
                sourceCommit: skill.sourceCommit,
                latestBackup: latestBackup
            )
        )
    }

    private func mergeAvailableSkills(_ details: [SkillDetail]) {
        for detail in details {
            if let index = availableSkills.firstIndex(where: { $0.summary.id == detail.summary.id }) {
                availableSkills[index] = detail
            } else {
                availableSkills.append(detail)
            }
        }
        availableSkills.sort { $0.summary.name.localizedCaseInsensitiveCompare($1.summary.name) == .orderedAscending }
    }

    private func upsertInstalledSkill(_ scannedSkill: ScannedInstalledSkill) {
        let skillID = SkillID("\(scannedSkill.rootURL.path)/\(scannedSkill.name)")
        let installedSkill = InstalledSkillViewState(
            id: UUID(),
            skillID: skillID,
            name: scannedSkill.name,
            description: scannedSkill.description,
            sourceLocation: scannedSkill.rootURL.path,
            targetDisplayName: scannedSkill.targetDisplayName,
            destination: scannedSkill.destination,
            installedHash: scannedSkill.installedHash,
            sourceCommit: nil,
            latestBackup: nil
        )

        if let index = installedSkills.firstIndex(where: { $0.destination == scannedSkill.destination }) {
            installedSkills[index] = installedSkill
        } else {
            installedSkills.append(installedSkill)
            installedSkills.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    private func detail(from scannedSkill: ScannedInstalledSkill) -> SkillDetail {
        let source = SkillSourceReference(kind: .local, location: scannedSkill.rootURL.path, trusted: true)
        let summary = SkillSummary(
            id: SkillID("\(scannedSkill.rootURL.path)/\(scannedSkill.name)"),
            name: scannedSkill.name,
            description: scannedSkill.description,
            source: source,
            installCount: nil,
            tags: [scannedSkill.targetDisplayName],
            lastUpdated: nil
        )

        return SkillDetail(
            summary: summary,
            readmeMarkdown: "",
            skillMarkdown: scannedSkill.skillMarkdown,
            sourceCommit: nil,
            contentHash: scannedSkill.installedHash,
            relativePath: scannedSkill.destination.path.replacingOccurrences(of: scannedSkill.rootURL.path + "/", with: "")
        )
    }

    private func sortedByInstallCount(_ skills: [SkillSummary]) -> [SkillSummary] {
        skills.sorted { left, right in
            let leftInstallCount = left.installCount ?? -1
            let rightInstallCount = right.installCount ?? -1
            if leftInstallCount == rightInstallCount {
                return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
            }
            return leftInstallCount > rightInstallCount
        }
    }

    private func appendLog(category: String, message: String) async {
        await logger.info(category: category, message: message)
        logs = await logger.entries()
    }

    private func setError(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}
