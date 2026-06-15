import Foundation
import AppKit
import SkillDeckSources

@MainActor
final class InstalledViewModel: ObservableObject {
    @Published private(set) var skills: [InstalledSkill] = []
    @Published private(set) var filteredSkills: [InstalledSkill] = []
    @Published private(set) var isLoading = false
    @Published private(set) var needsAccess = false
    @Published private(set) var errorMessage: String?
    @Published var searchText = ""

    private let scanner: InstalledSkillScanner
    private let bookmarkStore: SecurityScopedBookmarkStore

    init(
        scanner: InstalledSkillScanner = InstalledSkillScanner(),
        bookmarkStore: SecurityScopedBookmarkStore = SecurityScopedBookmarkStore()
    ) {
        self.scanner = scanner
        self.bookmarkStore = bookmarkStore
    }

    func loadInstalled() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let home: URL
        do {
            guard let resolved = try bookmarkStore.resolveURL() else {
                needsAccess = true
                skills = []
                filteredSkills = []
                return
            }
            home = resolved
        } catch {
            needsAccess = true
            errorMessage = error.localizedDescription
            return
        }

        needsAccess = false
        let didStartAccess = home.startAccessingSecurityScopedResource()
        defer { if didStartAccess { home.stopAccessingSecurityScopedResource() } }

        let roots = InstalledSkillScanner.defaultRoots(homeDirectory: home)
        skills = await scanner.scan(roots: roots)
        applyFilter()
    }

    /// Prompts the user to grant access to their home folder, persists a
    /// security-scoped bookmark, then rescans. The sandbox can only read the
    /// skills folders after the user selects an enclosing directory here.
    func requestAccess() async {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select your home folder so SkillDeck can read installed skills in ~/.claude, ~/.codex, and ~/.agents."
        panel.prompt = "Grant Access"
        if let realHome = Self.realHomeDirectory() {
            panel.directoryURL = realHome
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try bookmarkStore.save(url: url)
            await loadInstalled()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func revealInFinder(_ skill: InstalledSkill) {
        let url = URL(fileURLWithPath: skill.filePath).deletingLastPathComponent()
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }

    func updateSearch(_ text: String) {
        searchText = text
        applyFilter()
    }

    private func applyFilter() {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if query.isEmpty {
            filteredSkills = skills
        } else {
            filteredSkills = skills.filter { skill in
                skill.name.lowercased().contains(query) || skill.description.lowercased().contains(query)
            }
        }
    }

    /// Resolves the user's real home directory, bypassing the sandbox container
    /// that `FileManager.homeDirectoryForCurrentUser` reports. Used only to
    /// pre-position the open panel; access still requires user selection.
    private static func realHomeDirectory() -> URL? {
        guard let passwd = getpwuid(getuid()), let home = passwd.pointee.pw_dir else { return nil }
        let path = FileManager.default.string(withFileSystemRepresentation: home, length: strlen(home))
        return URL(fileURLWithPath: path, isDirectory: true)
    }
}
