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

struct InstalledSkillScanResult: Sendable {
    let skills: [ScannedInstalledSkill]
    let scannedRootURLs: [URL]
}

protocol InstalledSkillProviding: Sendable {
    func scanInstalledSkills() async throws -> InstalledSkillScanResult
}

struct FileSystemInstalledSkillProvider: InstalledSkillProviding {
    private let scanner: SkillDeckServices.InstalledSkillScanner
    private let roots: [SkillDeckServices.InstalledSkillScanRoot]?
    private let bookmarkStore: SecurityScopedBookmarkStore

    init(
        scanner: SkillDeckServices.InstalledSkillScanner = SkillDeckServices.InstalledSkillScanner(),
        roots: [SkillDeckServices.InstalledSkillScanRoot]? = nil,
        bookmarkStore: SecurityScopedBookmarkStore = SecurityScopedBookmarkStore()
    ) {
        self.scanner = scanner
        self.roots = roots
        self.bookmarkStore = bookmarkStore
    }

    func scanInstalledSkills() async throws -> InstalledSkillScanResult {
        if let roots {
            let scannedRoots = roots
                .map(\.url)
                .filter { FileManager.default.fileExists(atPath: $0.path) }
            return InstalledSkillScanResult(
                skills: try scanner.scan(roots: roots),
                scannedRootURLs: scannedRoots
            )
        }

        guard let grantedRoot = try bookmarkStore.resolveURL() else {
            return InstalledSkillScanResult(skills: [], scannedRootURLs: [])
        }

        let didStartAccess = grantedRoot.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                grantedRoot.stopAccessingSecurityScopedResource()
            }
        }

        let roots = Self.scanRoots(forGrantedRoot: grantedRoot)
        let scannedRoots = roots
            .map(\.url)
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        return InstalledSkillScanResult(
            skills: try scanner.scan(roots: roots),
            scannedRootURLs: scannedRoots
        )
    }

    static func scanRoots(forGrantedRoot grantedRoot: URL) -> [SkillDeckServices.InstalledSkillScanRoot] {
        let grantedRoot = grantedRoot.standardizedFileURL
        let rootConfigurations: [(agentDirectory: String, targetKind: AgentTargetKind, displayName: String)] = [
            (".agents", .codex, "Agents"),
            (".claude", .claudeCode, "Claude Code"),
            (".codex", .codex, "Codex"),
            (".copilot", .githubCopilot, "GitHub Copilot")
        ]

        for configuration in rootConfigurations {
            if grantedRoot.lastPathComponent == "skills",
               grantedRoot.deletingLastPathComponent().lastPathComponent == configuration.agentDirectory {
                return [SkillDeckServices.InstalledSkillScanRoot(
                    url: grantedRoot,
                    targetKind: configuration.targetKind,
                    displayName: configuration.displayName
                )]
            }

            if grantedRoot.lastPathComponent == configuration.agentDirectory {
                return [SkillDeckServices.InstalledSkillScanRoot(
                    url: grantedRoot.appendingPathComponent("skills", isDirectory: true),
                    targetKind: configuration.targetKind,
                    displayName: configuration.displayName
                )]
            }
        }

        return SkillDeckServices.InstalledSkillScanner.defaultRoots(homeDirectory: grantedRoot)
    }
}

struct InstalledSkillViewState: Identifiable, Equatable {
    let id: UUID
    var skillID: SkillID
    var name: String
    var description: String
    var sourceKind: SkillSourceKind
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

struct ManagedInstalledSkillRecord: Codable, Equatable {
    let skillID: SkillID
    let name: String
    let description: String
    let sourceKind: SkillSourceKind
    let sourceLocation: String
    let targetDisplayName: String
    let destination: URL
    let installedHash: String
    let sourceCommit: String?
}

extension ManagedInstalledSkillRecord {
    init(_ installedSkill: InstalledSkillViewState) {
        skillID = installedSkill.skillID
        name = installedSkill.name
        description = installedSkill.description
        sourceKind = installedSkill.sourceKind
        sourceLocation = installedSkill.sourceLocation
        targetDisplayName = installedSkill.targetDisplayName
        destination = installedSkill.destination
        installedHash = installedSkill.installedHash
        sourceCommit = installedSkill.sourceCommit
    }
}

protocol ManagedInstalledSkillPersisting {
    func loadRecords() -> [ManagedInstalledSkillRecord]
    func save(_ record: ManagedInstalledSkillRecord)
    func removeRecords(for destinations: Set<URL>)
}

final class UserDefaultsManagedInstalledSkillStore: ManagedInstalledSkillPersisting {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "managedInstalledSkills") {
        self.defaults = defaults
        self.key = key
    }

    func loadRecords() -> [ManagedInstalledSkillRecord] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([ManagedInstalledSkillRecord].self, from: data)) ?? []
    }

    func save(_ record: ManagedInstalledSkillRecord) {
        var records = loadRecords()
        let destination = record.destination.standardizedFileURL
        records.removeAll { $0.destination.standardizedFileURL == destination }
        records.append(record)
        save(records)
    }

    func removeRecords(for destinations: Set<URL>) {
        guard !destinations.isEmpty else { return }
        let standardizedDestinations = Set(destinations.map(\.standardizedFileURL))
        let records = loadRecords().filter { !standardizedDestinations.contains($0.destination.standardizedFileURL) }
        save(records)
    }

    private func save(_ records: [ManagedInstalledSkillRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: key)
    }
}

struct SkillConflictViewState: Equatable {
    let path: String
    let installedSkillID: UUID?
    let upstreamDetail: SkillDetail
    let installPreview: InstallPreview?
    let conflictingDestination: URL
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
    private let trendingProvider: SkillTrendingProviding
    private let detailProvider: SkillDetailProviding
    private let folderGrants: FolderGrantManaging
    private let backupManager: BackupManager
    private let installer: SkillInstaller
    private let logger: InMemoryAppLogService
    private let installedSkillsBookmarkStore: SecurityScopedBookmarkStore
    private let installedSkillProvider: InstalledSkillProviding
    private let managedInstallStore: ManagedInstalledSkillPersisting
    private var hasBootstrapped = false

    init(
        searchProvider: SkillSearchProviding = SkillsShSearchProvider(),
        trendingProvider: SkillTrendingProviding = SkillsShTrendingProvider(),
        detailProvider: SkillDetailProviding = GitHubSkillSourceProvider(),
        folderGrants: FolderGrantManaging = InMemoryFolderGrantStore(),
        backupRoot: URL = (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("SkillDeck/Backups", isDirectory: true),
        installer: SkillInstaller = SkillInstaller(),
        logger: InMemoryAppLogService = InMemoryAppLogService(),
        installedSkillsBookmarkStore: SecurityScopedBookmarkStore = SecurityScopedBookmarkStore(),
        installedSkillProvider: InstalledSkillProviding? = nil,
        managedInstallStore: ManagedInstalledSkillPersisting = UserDefaultsManagedInstalledSkillStore()
    ) {
        self.searchProvider = searchProvider
        self.trendingProvider = trendingProvider
        self.detailProvider = detailProvider
        self.folderGrants = folderGrants
        self.backupManager = BackupManager(backupRoot: backupRoot)
        self.installer = installer
        self.logger = logger
        self.installedSkillsBookmarkStore = installedSkillsBookmarkStore
        self.installedSkillProvider = installedSkillProvider ?? FileSystemInstalledSkillProvider(bookmarkStore: installedSkillsBookmarkStore)
        self.managedInstallStore = managedInstallStore
    }

    func bootstrap() async {
        guard !hasBootstrapped else { return }
        errorMessage = nil
        await loadInitialCatalog()
        await syncInstalledSkills()
        if errorMessage == nil {
            hasBootstrapped = true
        }
    }

    func loadInitialCatalog() async {
        do {
            let results = try await trendingProvider.trending(limit: 25)
            catalogSkills = sortedByInstallCount(results)
            searchResults = catalogSkills
            await appendLog(category: "Discovery", message: "Loaded \(catalogSkills.count) top skills")
        } catch {
            setError(error)
        }
    }

    func syncInstalledSkills() async {
        do {
            let scanResult = try await installedSkillProvider.scanInstalledSkills()
            let scannedDestinations = Set(scanResult.skills.map { $0.destination.standardizedFileURL })
            let scannedRoots = scanResult.scannedRootURLs.map(\.standardizedFileURL)
            let persistedManagedRecords = managedInstallStore.loadRecords()
            var persistedManagedByDestination: [URL: ManagedInstalledSkillRecord] = [:]
            for record in persistedManagedRecords {
                persistedManagedByDestination[record.destination.standardizedFileURL] = record
            }
            let staleManagedDestinations = persistedManagedRecords.compactMap { record -> URL? in
                let destination = record.destination.standardizedFileURL
                guard scannedRoots.contains(where: { isDescendant(destination, of: $0) }),
                      !scannedDestinations.contains(destination) else {
                    return nil
                }
                return destination
            }
            managedInstallStore.removeRecords(for: Set(staleManagedDestinations))

            installedSkills.removeAll { installedSkill in
                if scannedRoots.isEmpty {
                    return installedSkill.sourceKind == .local
                        && !scannedDestinations.contains(installedSkill.destination.standardizedFileURL)
                }

                guard scannedRoots.contains(where: { isDescendant(installedSkill.destination, of: $0) }) else {
                    return false
                }
                return !scannedDestinations.contains(installedSkill.destination.standardizedFileURL)
            }

            let installedSkillIDs = Set(installedSkills.map(\.id))
            availableUpdates.removeAll { !installedSkillIDs.contains($0.installedSkillID) }
            pruneStaleLocalDetails(scannedSkillIDs: Set(scanResult.skills.map { localSkillID(for: $0) }), scannedRoots: scannedRoots)

            for scannedSkill in scanResult.skills {
                let persistedManagedRecord = persistedManagedByDestination[scannedSkill.destination.standardizedFileURL]
                mergeAvailableSkills([detail(from: scannedSkill, persistedManagedRecord: persistedManagedRecord)])
                upsertInstalledSkill(scannedSkill, persistedManagedRecord: persistedManagedRecord)
            }
            installedSkills.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            await appendLog(category: "Install", message: "Synced \(scanResult.skills.count) installed skills")
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

    func grantInstalledSkillsFolder(_ folder: URL) async {
        do {
            try installedSkillsBookmarkStore.save(url: folder)
            await syncInstalledSkills()
        } catch {
            setError(error)
        }
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
            guard installedSkill.sourceKind == .github else {
                continue
            }

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
                    upstreamDetail: update.upstreamDetail,
                    installPreview: nil,
                    conflictingDestination: installedSkill.destination
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
        guard let pendingConflict else { return }

        if let installPreview = pendingConflict.installPreview {
            try await performInstall(skill: pendingConflict.upstreamDetail, preview: installPreview)
            self.pendingConflict = nil
            return
        }

        guard let installedSkillID = pendingConflict.installedSkillID,
              let installedSkill = installedSkills.first(where: { $0.id == installedSkillID }) else {
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
        persistManagedInstalledSkill(installedSkills[index])
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
                installedSkillID: conflict.installedSkill?.id,
                upstreamDetail: skill,
                installPreview: preview,
                conflictingDestination: conflict.destination
            )
            await appendLog(category: "Install", message: "Conflict detected for \(conflict.installedSkill?.name ?? skill.summary.name)")
            return
        }

        try await performInstall(skill: skill, preview: preview)
    }

    private func performInstall(skill: SkillDetail, preview: InstallPreview) async throws {
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
        try validateWriteGrant(for: installedSkill.destination)
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
        mergeAvailableSkills([upstream])
        if selectedSkill?.summary.id == upstream.summary.id {
            selectedSkill = upstream
        }
        availableUpdates.removeAll { $0.installedSkillID == installedSkill.id }
        await appendLog(category: "Update", message: "Updated \(upstream.summary.name)")
    }

    private func firstConflict(in preview: InstallPreview) throws -> (installedSkill: InstalledSkillViewState?, destination: URL)? {
        for destination in preview.destinations where FileManager.default.fileExists(atPath: destination.path) {
            guard let installedSkill = installedSkills.first(where: { $0.destination == destination }) else {
                return (nil, destination)
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

    private func validateWriteGrant(for destination: URL) throws {
        guard try folderGrants.canWrite(to: destination) else {
            throw SkillDeckError.folderGrantMissing(destination.deletingLastPathComponent().path)
        }
    }

    private func isDescendant(_ url: URL, of root: URL) -> Bool {
        let urlPath = url.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path
        return urlPath == rootPath || urlPath.hasPrefix(rootPath + "/")
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
            installedSkills[index].sourceKind = skill.summary.source.kind
            installedSkills[index].sourceLocation = skill.summary.source.location
            installedSkills[index].targetDisplayName = "Managed"
            installedSkills[index].installedHash = installedHash
            installedSkills[index].sourceCommit = skill.sourceCommit
            installedSkills[index].latestBackup = latestBackup ?? installedSkills[index].latestBackup
            persistManagedInstalledSkill(installedSkills[index])
            return
        }

        let installedSkill = InstalledSkillViewState(
            id: UUID(),
            skillID: skill.summary.id,
            name: skill.summary.name,
            description: skill.summary.description,
            sourceKind: skill.summary.source.kind,
            sourceLocation: skill.summary.source.location,
            targetDisplayName: "Managed",
            destination: destination,
            installedHash: installedHash,
            sourceCommit: skill.sourceCommit,
            latestBackup: latestBackup
        )
        installedSkills.append(installedSkill)
        persistManagedInstalledSkill(installedSkill)
    }

    private func persistManagedInstalledSkill(_ installedSkill: InstalledSkillViewState) {
        guard installedSkill.sourceKind == .github else { return }
        managedInstallStore.save(ManagedInstalledSkillRecord(installedSkill))
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

    private func pruneStaleLocalDetails(scannedSkillIDs: Set<SkillID>, scannedRoots: [URL]) {
        availableSkills.removeAll { detail in
            guard detail.summary.source.kind == .local else { return false }
            guard !scannedRoots.isEmpty else { return true }

            let sourceURL = URL(fileURLWithPath: detail.summary.source.location, isDirectory: true).standardizedFileURL
            guard scannedRoots.contains(where: { isDescendant(sourceURL, of: $0) || isDescendant($0, of: sourceURL) }) else {
                return false
            }
            return !scannedSkillIDs.contains(detail.summary.id)
        }

        if let selectedSkill,
           selectedSkill.summary.source.kind == .local,
           !availableSkills.contains(where: { $0.summary.id == selectedSkill.summary.id }) {
            self.selectedSkill = nil
        }
    }

    private func localSkillID(for scannedSkill: ScannedInstalledSkill) -> SkillID {
        SkillID("\(scannedSkill.rootURL.path)/\(scannedSkill.name)")
    }

    private func upsertInstalledSkill(_ scannedSkill: ScannedInstalledSkill, persistedManagedRecord: ManagedInstalledSkillRecord? = nil) {
        let skillID = persistedManagedRecord?.skillID ?? localSkillID(for: scannedSkill)

        if let index = installedSkills.firstIndex(where: { $0.destination.standardizedFileURL == scannedSkill.destination.standardizedFileURL }) {
            let preservesManagedSource = installedSkills[index].sourceKind == .github || persistedManagedRecord != nil
            installedSkills[index].skillID = preservesManagedSource ? skillID : localSkillID(for: scannedSkill)
            installedSkills[index].name = scannedSkill.name
            installedSkills[index].description = scannedSkill.description
            installedSkills[index].sourceKind = preservesManagedSource ? (persistedManagedRecord?.sourceKind ?? installedSkills[index].sourceKind) : .local
            installedSkills[index].sourceLocation = preservesManagedSource ? (persistedManagedRecord?.sourceLocation ?? installedSkills[index].sourceLocation) : scannedSkill.rootURL.path
            installedSkills[index].targetDisplayName = scannedSkill.targetDisplayName
            installedSkills[index].installedHash = preservesManagedSource ? (persistedManagedRecord?.installedHash ?? installedSkills[index].installedHash) : scannedSkill.installedHash
            installedSkills[index].sourceCommit = preservesManagedSource ? (persistedManagedRecord?.sourceCommit ?? installedSkills[index].sourceCommit) : nil
        } else {
            installedSkills.append(
                InstalledSkillViewState(
                    id: UUID(),
                    skillID: skillID,
                    name: scannedSkill.name,
                    description: scannedSkill.description,
                    sourceKind: persistedManagedRecord?.sourceKind ?? .local,
                    sourceLocation: persistedManagedRecord?.sourceLocation ?? scannedSkill.rootURL.path,
                    targetDisplayName: scannedSkill.targetDisplayName,
                    destination: scannedSkill.destination,
                    installedHash: persistedManagedRecord?.installedHash ?? scannedSkill.installedHash,
                    sourceCommit: persistedManagedRecord?.sourceCommit,
                    latestBackup: nil
                )
            )
        }
        if let installedSkill = installedSkills.first(where: { $0.destination.standardizedFileURL == scannedSkill.destination.standardizedFileURL }) {
            persistManagedInstalledSkill(installedSkill)
        }
    }

    private func detail(from scannedSkill: ScannedInstalledSkill, persistedManagedRecord: ManagedInstalledSkillRecord? = nil) -> SkillDetail {
        let source = SkillSourceReference(
            kind: persistedManagedRecord?.sourceKind ?? .local,
            location: persistedManagedRecord?.sourceLocation ?? scannedSkill.rootURL.path,
            trusted: true
        )
        let summary = SkillSummary(
            id: persistedManagedRecord?.skillID ?? localSkillID(for: scannedSkill),
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
            sourceCommit: persistedManagedRecord?.sourceCommit,
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
