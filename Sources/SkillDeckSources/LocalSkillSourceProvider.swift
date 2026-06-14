import Foundation
import SkillDeckCore

public struct LocalSkillSourceProvider: Sendable {
    public init() {}

    public func scanRepository(at root: URL, source: SkillSourceReference) async throws -> [SkillSummary] {
        let candidates = try skillManifestURLs(inside: root)
        var summaries: [SkillSummary] = []

        for candidate in candidates {
            let markdown = try String(contentsOf: candidate, encoding: .utf8)
            let manifest = try SkillManifestParser.parse(markdown)
            summaries.append(
                SkillSummary(
                    id: SkillID("\(source.location)/\(manifest.name)"),
                    name: manifest.name,
                    description: manifest.description,
                    source: source,
                    installCount: nil,
                    tags: [],
                    lastUpdated: nil
                )
            )
        }

        return summaries.sorted { $0.name < $1.name }
    }

    private func skillManifestURLs(inside root: URL) throws -> [URL] {
        let supportedRoots = [
            root,
            root.appendingPathComponent("skills"),
            root.appendingPathComponent(".claude/skills"),
            root.appendingPathComponent(".agents/skills")
        ]

        var results: [URL] = []
        for supportedRoot in supportedRoots where FileManager.default.fileExists(atPath: supportedRoot.path) {
            let enumerator = FileManager.default.enumerator(
                at: supportedRoot,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            while let file = enumerator?.nextObject() as? URL {
                if file.lastPathComponent == "SKILL.md" {
                    results.append(file)
                }
            }
        }

        return Array(Set(results)).sorted { $0.path < $1.path }
    }
}
