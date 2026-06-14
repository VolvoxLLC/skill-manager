import Foundation
import SkillDeckCore

public struct GitHubRepositorySnapshot: Sendable {
    public let repository: GitHubRepository
    public let commit: String
    public let files: [String: String]

    public init(repository: GitHubRepository, commit: String, files: [String: String]) {
        self.repository = repository
        self.commit = commit
        self.files = files
    }
}

public protocol GitHubRepositoryFetching: Sendable {
    func fetchRepositoryFiles(_ repository: GitHubRepository) async throws -> GitHubRepositorySnapshot
}

public struct GitHubRepositoryClient: GitHubRepositoryFetching {
    private let httpClient: HTTPClient

    public init(httpClient: HTTPClient = URLSessionHTTPClient()) {
        self.httpClient = httpClient
    }

    public func fetchRepositoryFiles(_ repository: GitHubRepository) async throws -> GitHubRepositorySnapshot {
        let ref = repository.ref ?? "HEAD"
        let treeURL = URL(string: "https://api.github.com/repos/\(repository.owner)/\(repository.name)/git/trees/\(ref)?recursive=1")!
        let treeResponse = try await httpClient.data(for: makeRequest(url: treeURL))

        if treeResponse.statusCode == 403 {
            throw SkillDeckError.githubRateLimited
        }
        guard treeResponse.statusCode == 200 else {
            throw SkillDeckError.sourceUnavailable("GitHub tree returned HTTP \(treeResponse.statusCode)")
        }

        let tree = try JSONDecoder().decode(GitHubTreeResponse.self, from: treeResponse.data)
        let markdownEntries = tree.tree.filter { entry in
            entry.type == "blob" && (entry.path.hasSuffix("SKILL.md") || entry.path.hasSuffix("README.md"))
        }

        var files: [String: String] = [:]
        for entry in markdownEntries {
            let rawURL = URL(string: "https://raw.githubusercontent.com/\(repository.owner)/\(repository.name)/\(tree.sha)/\(entry.path)")!
            let fileResponse = try await httpClient.data(for: makeRequest(url: rawURL))
            guard fileResponse.statusCode == 200 else { continue }
            files[entry.path] = String(data: fileResponse.data, encoding: .utf8) ?? ""
        }

        return GitHubRepositorySnapshot(repository: repository, commit: tree.sha, files: files)
    }

    private func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        // GitHub's API rejects requests without a User-Agent with HTTP 403.
        request.setValue("SkillDeck", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        return request
    }
}

private struct GitHubTreeResponse: Decodable {
    let sha: String
    let tree: [GitHubTreeEntry]
}

private struct GitHubTreeEntry: Decodable {
    let path: String
    let type: String
}
