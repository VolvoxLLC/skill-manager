import Foundation
import SkillDeckCore

/// Scans installed-skill root directories and returns skills with their installation targets.
public struct InstalledSkillScanner {
    private let fileManager = FileManager.default

    public init() {}

    /// Root directory with its display label for a skill source.
    public struct Root {
        public let label: String
        public let path: URL

        public init(label: String, path: URL) {
            self.label = label
            self.path = path
        }
    }

    /// Default roots: ~/.codex/skills, ~/.claude/skills, ~/.agents/skills.
    public static func defaultRoots(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> [Root] {
        [
            Root(label: "Codex", path: homeDirectory.appendingPathComponent(".codex/skills")),
            Root(label: "Claude Code", path: homeDirectory.appendingPathComponent(".claude/skills")),
            Root(label: "Agents", path: homeDirectory.appendingPathComponent(".agents/skills"))
        ]
    }

    /// Scans the given roots for installed skills, deduplicating by real path and merging targets.
    /// Tolerates malformed SKILL.md files and missing roots.
    public func scan(roots: [Root]) async -> [InstalledSkill] {
        var skillsByRealPath: [String: InstalledSkill] = [:]
        var targetsByRealPath: [String: Set<String>] = [:]

        for root in roots {
            guard fileManager.fileExists(atPath: root.path.path) else { continue }

            let skills = scanDirectory(root.path)
            for skill in skills {
                let realPath = skill.filePath
                targetsByRealPath[realPath, default: []].insert(root.label)

                if skillsByRealPath[realPath] == nil {
                    skillsByRealPath[realPath] = skill
                }
            }
        }

        var deduped: [String: InstalledSkill] = [:]
        for (realPath, skill) in skillsByRealPath {
            let targets = Array(targetsByRealPath[realPath] ?? []).sorted()
            var updated = skill
            updated.targets = targets
            deduped[skill.name] = updated
        }

        return deduped.values.sorted { $0.name < $1.name }
    }

    private func scanDirectory(_ root: URL) -> [InstalledSkill] {
        var results: [InstalledSkill] = []
        var visitedRealPaths = Set<String>()
        var stack = [root]

        while !stack.isEmpty {
            var current = stack.removeLast()
            current = current.resolvingSymlinksInPath()

            do {
                let contents = try fileManager.contentsOfDirectory(at: current, includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .isSymbolicLinkKey])

                for item in contents {
                    let name = item.lastPathComponent
                    if name.hasPrefix(".") { continue }

                    if name == "SKILL.md" {
                        do {
                            let realPath = item.resolvingSymlinksInPath().path
                            guard !visitedRealPaths.contains(realPath) else { continue }
                            visitedRealPaths.insert(realPath)

                            let markdown = try String(contentsOf: item, encoding: .utf8)
                            let manifest = try SkillManifestParser.parse(markdown)
                            let modDate = try item.resourceValues(forKeys: [URLResourceKey.contentModificationDateKey]).contentModificationDate

                            results.append(InstalledSkill(
                                name: manifest.name,
                                description: manifest.description,
                                targets: [],
                                filePath: realPath,
                                lastModified: modDate
                            ))
                        } catch {
                            continue
                        }
                    } else {
                        let values = try item.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                        let isDir = values.isDirectory ?? false
                        let isSymlink = values.isSymbolicLink ?? false

                        if isDir || isSymlink {
                            let targetURL: URL
                            if isSymlink {
                                targetURL = item.resolvingSymlinksInPath()
                            } else {
                                targetURL = item
                            }

                            var isTargetDir = false
                            if let targetIsDir = try targetURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory {
                                isTargetDir = targetIsDir
                            }

                            if isTargetDir {
                                stack.append(item)
                            }
                        }
                    }
                }
            } catch {
                continue
            }
        }

        return results
    }
}

/// A skill installed locally on the system.
public struct InstalledSkill: Identifiable, Sendable {
    public let id: String

    public let name: String
    public let description: String
    public var targets: [String]
    public let filePath: String
    public let lastModified: Date?

    public init(
        name: String,
        description: String,
        targets: [String] = [],
        filePath: String,
        lastModified: Date?
    ) {
        self.name = name
        self.description = description
        self.targets = targets
        self.filePath = filePath
        self.lastModified = lastModified
        self.id = name
    }
}
