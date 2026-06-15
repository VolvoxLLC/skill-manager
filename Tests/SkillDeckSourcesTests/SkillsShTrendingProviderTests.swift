import XCTest
@testable import SkillDeckCore
@testable import SkillDeckSources

final class SkillsShTrendingProviderTests: XCTestCase {
    func testParsesAndSortsLeaderboardByInstallsDescending() async throws {
        let payload = """
        3:["$","div",null,{"children":[\
        {"source":"owner/low","skillId":"low","name":"low","installs":10},\
        {"source":"owner/high","skillId":"high","name":"high","installs":900},\
        {"source":"owner/mid","skillId":"mid","name":"mid","installs":100}\
        ]}]
        """.data(using: .utf8)!

        let client = MockHTTPClient(data: payload, statusCode: 200)
        let provider = SkillsShTrendingProvider(httpClient: client)

        let results = try await provider.trending(limit: 25)

        XCTAssertEqual(results.map(\.name), ["high", "mid", "low"])
        XCTAssertEqual(results[0].installCount, 900)
        XCTAssertEqual(results[0].id.rawValue, "owner/high/high")
        XCTAssertEqual(results[0].source.location, "owner/high")
        XCTAssertEqual(results[0].source.kind, .skillsSh)
        XCTAssertTrue(results[0].source.trusted)
    }

    func testDeduplicatesRepeatedSkillsKeepingHighestInstallCount() async throws {
        let payload = """
        {"source":"owner/dup","skillId":"dup","name":"dup","installs":50}\
        {"source":"owner/dup","skillId":"dup","name":"dup","installs":80}\
        {"source":"owner/other","skillId":"other","name":"other","installs":70}
        """.data(using: .utf8)!

        let client = MockHTTPClient(data: payload, statusCode: 200)
        let provider = SkillsShTrendingProvider(httpClient: client)

        let results = try await provider.trending(limit: 25)

        XCTAssertEqual(results.map(\.name), ["dup", "other"])
        XCTAssertEqual(results[0].installCount, 80)
    }

    func testRespectsLimit() async throws {
        let payload = """
        {"source":"o/a","skillId":"a","name":"a","installs":3}\
        {"source":"o/b","skillId":"b","name":"b","installs":2}\
        {"source":"o/c","skillId":"c","name":"c","installs":1}
        """.data(using: .utf8)!

        let client = MockHTTPClient(data: payload, statusCode: 200)
        let provider = SkillsShTrendingProvider(httpClient: client)

        let results = try await provider.trending(limit: 2)

        XCTAssertEqual(results.map(\.name), ["a", "b"])
    }

    func testThrowsWhenServerReturnsNon200() async {
        let client = MockHTTPClient(data: Data(), statusCode: 503)
        let provider = SkillsShTrendingProvider(httpClient: client)

        do {
            _ = try await provider.trending(limit: 25)
            XCTFail("Expected an error for non-200 response")
        } catch let error as SkillDeckError {
            XCTAssertEqual(error, .sourceUnavailable("skills.sh trending returned HTTP 503"))
        } catch {
            XCTFail("Expected SkillDeckError, got \(error)")
        }
    }
}

private struct MockHTTPClient: HTTPClient {
    let data: Data
    let statusCode: Int

    func data(for request: URLRequest) async throws -> HTTPResponse {
        HTTPResponse(data: data, statusCode: statusCode)
    }
}
