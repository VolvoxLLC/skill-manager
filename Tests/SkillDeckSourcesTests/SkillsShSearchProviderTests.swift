import XCTest
@testable import SkillDeckCore
@testable import SkillDeckSources

final class SkillsShSearchProviderTests: XCTestCase {
    func testParsesPublicSearchResponse() async throws {
        let json = """
        {
          "query": "typescript",
          "skills": [
            {
              "id": "github/awesome-copilot/typescript-mcp-server-generator",
              "skillId": "typescript-mcp-server-generator",
              "name": "typescript-mcp-server-generator",
              "installs": 10611,
              "source": "github/awesome-copilot"
            }
          ],
          "count": 1
        }
        """.data(using: .utf8)!

        let client = MockHTTPClient(data: json, statusCode: 200)
        let provider = SkillsShSearchProvider(httpClient: client)

        let results = try await provider.search(query: "typescript", limit: 1)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "typescript-mcp-server-generator")
        XCTAssertEqual(results[0].installCount, 10611)
        XCTAssertEqual(results[0].source.location, "github/awesome-copilot")
        XCTAssertTrue(results[0].source.trusted)
    }
}

private struct MockHTTPClient: HTTPClient {
    let data: Data
    let statusCode: Int

    func data(for request: URLRequest) async throws -> HTTPResponse {
        HTTPResponse(data: data, statusCode: statusCode)
    }
}
