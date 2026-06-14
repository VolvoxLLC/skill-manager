import Foundation
import SkillDeckCore

public struct GitHubSkillSourceProvider: Sendable {
    private let client: GitHubRepositoryFetching

    public init(client: GitHubRepositoryFetching = GitHubRepositoryClient()) {
        self.client = client
    }

    public func scan(source: String) async throws -> [SkillDetail] {
        let repository = try GitHubURLParser.parse(source)
        let snapshot = try await client.fetchRepositoryFiles(repository)

        return try snapshot.files
            .filter { $0.key.hasSuffix("SKILL.md") }
            .map { path, markdown in
                let manifest = try SkillManifestParser.parse(markdown)
                let readmePath = path.replacingOccurrences(of: "SKILL.md", with: "README.md")
                let summary = SkillSummary(
                    id: SkillID("\(repository.slug)/\(manifest.name)"),
                    name: manifest.name,
                    description: manifest.description,
                    source: SkillSourceReference(kind: .github, location: repository.slug, trusted: true),
                    installCount: nil,
                    tags: [],
                    lastUpdated: nil
                )
                return SkillDetail(
                    summary: summary,
                    readmeMarkdown: snapshot.files[readmePath] ?? "",
                    skillMarkdown: markdown,
                    sourceCommit: snapshot.commit,
                    contentHash: ContentHasher.sha256Hex(markdown),
                    relativePath: path
                )
            }
            .sorted { $0.summary.name < $1.summary.name }
    }
}
