import Foundation
import SkillDeckCore
import SkillDeckSources

@MainActor
final class DiscoverViewModel: ObservableObject {
    @Published private(set) var results: [SkillSummary] = []
    @Published private(set) var canLoadMore = false
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let searchProvider: SkillSearchProviding
    private let trendingProvider: SkillTrendingProviding
    private var hasLoadedTrending = false

    private var fullResults: [SkillSummary] = []
    private let pageSize = 25
    private var currentPage = 0

    init(searchProvider: SkillSearchProviding, trendingProvider: SkillTrendingProviding) {
        self.searchProvider = searchProvider
        self.trendingProvider = trendingProvider
    }

    /// Loads the skills.sh trending leaderboard once, the first time the view appears.
    /// Subsequent calls are no-ops so navigating away and back does not refetch.
    func loadTrending() async {
        guard !hasLoadedTrending else { return }
        hasLoadedTrending = true

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            fullResults = try await trendingProvider.trending(limit: 100)
            currentPage = 0
            revealNextPage()
        } catch {
            fullResults = []
            results = []
            errorMessage = error.localizedDescription
        }
    }

    func search(_ query: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            fullResults = try await searchProvider.search(query: query, limit: 100)
            currentPage = 0
            results = []
            revealNextPage()
        } catch {
            fullResults = []
            results = []
            errorMessage = error.localizedDescription
        }
    }

    /// Loads the next page of results if available. Called when scrolling near the end.
    func loadMoreIfNeeded(currentItem: SkillSummary) {
        let threshold = pageSize / 2
        let itemIndex = results.firstIndex(of: currentItem) ?? -1

        if itemIndex >= results.count - threshold && results.count < fullResults.count {
            revealNextPage()
        }
    }

    private func revealNextPage() {
        let startIndex = currentPage * pageSize
        let endIndex = min(startIndex + pageSize, fullResults.count)

        if startIndex < fullResults.count {
            results.append(contentsOf: fullResults[startIndex..<endIndex])
            currentPage += 1
            canLoadMore = results.count < fullResults.count
        }
    }
}
