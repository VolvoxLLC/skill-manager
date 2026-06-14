import XCTest
@testable import SkillDeck
import SkillDeckCore
import SkillDeckSources

@MainActor
final class DiscoverViewModelTests: XCTestCase {
    func testSearchStoresResults() async {
        let provider = MockSearchProvider(results: [
            SkillSummary(
                id: SkillID("source/demo"),
                name: "demo",
                description: "Demo",
                source: SkillSourceReference(kind: .skillsSh, location: "source", trusted: true),
                installCount: 1,
                tags: [],
                lastUpdated: nil
            )
        ])
        let viewModel = DiscoverViewModel(searchProvider: provider)

        await viewModel.search("demo")

        XCTAssertEqual(viewModel.results.map(\.name), ["demo"])
        XCTAssertNil(viewModel.errorMessage)
    }
}

private struct MockSearchProvider: SkillSearchProviding {
    let results: [SkillSummary]

    func search(query: String, limit: Int) async throws -> [SkillSummary] {
        results
    }
}
