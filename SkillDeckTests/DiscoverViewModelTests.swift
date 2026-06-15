import XCTest
@testable import SkillDeck
import SkillDeckCore
import SkillDeckSources

@MainActor
final class DiscoverViewModelTests: XCTestCase {
    func testSearchStoresResults() async {
        let viewModel = DiscoverViewModel(
            searchProvider: MockSearchProvider(results: [Self.summary(named: "demo")]),
            trendingProvider: MockTrendingProvider(results: [])
        )

        await viewModel.search("demo")

        XCTAssertEqual(viewModel.results.map(\.name), ["demo"])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoadTrendingPopulatesResults() async {
        let viewModel = DiscoverViewModel(
            searchProvider: MockSearchProvider(results: []),
            trendingProvider: MockTrendingProvider(results: [Self.summary(named: "top-skill")])
        )

        await viewModel.loadTrending()

        XCTAssertEqual(viewModel.results.map(\.name), ["top-skill"])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoadTrendingRunsOnlyOnce() async {
        let trending = MockTrendingProvider(results: [Self.summary(named: "top-skill")])
        let viewModel = DiscoverViewModel(
            searchProvider: MockSearchProvider(results: []),
            trendingProvider: trending
        )

        await viewModel.loadTrending()
        await viewModel.loadTrending()

        XCTAssertEqual(trending.callCount, 1)
    }

    func testLoadTrendingSurfacesError() async {
        let viewModel = DiscoverViewModel(
            searchProvider: MockSearchProvider(results: []),
            trendingProvider: MockTrendingProvider(error: SkillDeckError.sourceUnavailable("trending"))
        )

        await viewModel.loadTrending()

        XCTAssertTrue(viewModel.results.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    private static func summary(named name: String) -> SkillSummary {
        SkillSummary(
            id: SkillID("source/\(name)"),
            name: name,
            description: "",
            source: SkillSourceReference(kind: .skillsSh, location: "source", trusted: true),
            installCount: 1,
            tags: [],
            lastUpdated: nil
        )
    }
}

private struct MockSearchProvider: SkillSearchProviding {
    let results: [SkillSummary]

    func search(query: String, limit: Int) async throws -> [SkillSummary] {
        results
    }
}

private final class MockTrendingProvider: SkillTrendingProviding, @unchecked Sendable {
    private let results: [SkillSummary]
    private let error: Error?
    private(set) var callCount = 0

    init(results: [SkillSummary] = [], error: Error? = nil) {
        self.results = results
        self.error = error
    }

    func trending(limit: Int) async throws -> [SkillSummary] {
        callCount += 1
        if let error { throw error }
        return results
    }
}
