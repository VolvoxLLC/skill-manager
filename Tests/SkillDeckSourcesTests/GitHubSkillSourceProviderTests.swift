import XCTest
@testable import SkillDeckCore
@testable import SkillDeckSources

final class GitHubSkillSourceProviderTests: XCTestCase {
    func testBuildsSkillDetailFromFetchedRepositoryFiles() async throws {
        let files = [
            "skills/swiftui-helper/SKILL.md": """
            ---
            name: swiftui-helper
            description: Helps build SwiftUI views
            ---

            # Skill
            """,
            "skills/swiftui-helper/README.md": "# Readme"
        ]
        let client = MockGitHubRepositoryClient(files: files, commit: "abc123")
        let provider = GitHubSkillSourceProvider(client: client)

        let details = try await provider.scan(source: "owner/repo")

        XCTAssertEqual(details.count, 1)
        XCTAssertEqual(details[0].summary.name, "swiftui-helper")
        XCTAssertEqual(details[0].sourceCommit, "abc123")
        XCTAssertEqual(details[0].summary.source.location, "owner/repo")
        XCTAssertEqual(details[0].readmeMarkdown, "# Readme")
        XCTAssertEqual(details[0].relativePath, "skills/swiftui-helper/SKILL.md")
    }

    func testPreservesRefQualifiedSourceLocationForUpdates() async throws {
        let files = [
            "skills/ref-skill/SKILL.md": """
            ---
            name: ref-skill
            description: Ref skill
            ---
            """
        ]
        let client = MockGitHubRepositoryClient(files: files, commit: "abc123")
        let provider = GitHubSkillSourceProvider(client: client)

        let details = try await provider.scan(source: "owner/repo#release")

        XCTAssertEqual(details[0].summary.id.rawValue, "owner/repo#release/ref-skill")
        XCTAssertEqual(details[0].summary.source.location, "owner/repo#release")
    }

    func testGitHubRepositoryClientFetchesTreeAndMarkdownFiles() async throws {
        let treeURL = "https://api.github.com/repos/owner/repo/git/trees/main?recursive=1"
        let skillURL = "https://raw.githubusercontent.com/owner/repo/tree123/skills/demo/SKILL.md"
        let readmeURL = "https://raw.githubusercontent.com/owner/repo/tree123/skills/demo/README.md"

        let treeJSON = """
        {
          "sha": "tree123",
          "tree": [
            { "path": "skills/demo/SKILL.md", "type": "blob" },
            { "path": "skills/demo/README.md", "type": "blob" },
            { "path": "assets/logo.png", "type": "blob" }
          ]
        }
        """.data(using: .utf8)!

        let client = RoutingHTTPClient(routes: [
            treeURL: HTTPResponse(data: treeJSON, statusCode: 200),
            skillURL: HTTPResponse(data: Data("---\nname: demo\ndescription: Demo\n---".utf8), statusCode: 200),
            readmeURL: HTTPResponse(data: Data("# Demo".utf8), statusCode: 200)
        ])
        let repositoryClient = GitHubRepositoryClient(httpClient: client)

        let snapshot = try await repositoryClient.fetchRepositoryFiles(
            GitHubRepository(owner: "owner", name: "repo", ref: "main")
        )

        XCTAssertEqual(snapshot.commit, "tree123")
        XCTAssertEqual(snapshot.files["skills/demo/SKILL.md"], "---\nname: demo\ndescription: Demo\n---")
        XCTAssertEqual(snapshot.files["skills/demo/README.md"], "# Demo")
        XCTAssertNil(snapshot.files["assets/logo.png"])
    }
}

private struct MockGitHubRepositoryClient: GitHubRepositoryFetching {
    let files: [String: String]
    let commit: String

    func fetchRepositoryFiles(_ repository: GitHubRepository) async throws -> GitHubRepositorySnapshot {
        GitHubRepositorySnapshot(repository: repository, commit: commit, files: files)
    }
}

private struct RoutingHTTPClient: HTTPClient {
    let routes: [String: HTTPResponse]

    func data(for request: URLRequest) async throws -> HTTPResponse {
        guard let url = request.url?.absoluteString, let response = routes[url] else {
            return HTTPResponse(data: Data(), statusCode: 404)
        }
        return response
    }
}
