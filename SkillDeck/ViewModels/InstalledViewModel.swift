import Foundation
import AppKit
import SkillDeckSources

@MainActor
final class InstalledViewModel: ObservableObject {
    @Published private(set) var skills: [InstalledSkill] = []
    @Published private(set) var filteredSkills: [InstalledSkill] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var searchText = ""

    private let scanner: InstalledSkillScanner
    private let roots: [InstalledSkillScanner.Root]

    init(scanner: InstalledSkillScanner = InstalledSkillScanner(), roots: [InstalledSkillScanner.Root]? = nil) {
        self.scanner = scanner
        self.roots = roots ?? InstalledSkillScanner.defaultRoots()
    }

    func loadInstalled() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        skills = await scanner.scan(roots: roots)
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

    func updateSearch(_ text: String) {
        searchText = text
        applyFilter()
    }

    func revealInFinder(_ skill: InstalledSkill) {
        let url = URL(fileURLWithPath: skill.filePath).deletingLastPathComponent()
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }
}
