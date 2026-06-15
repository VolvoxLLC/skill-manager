import Foundation
import SkillDeckCore
import SkillDeckSources

@MainActor
final class DiscoverViewModel: ObservableObject {
    @Published private(set) var results: [SkillSummary] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let searchProvider: SkillSearchProviding
    private let trendingProvider: SkillTrendingProviding
    private var hasLoadedTrending = false

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
            results = try await trendingProvider.trending(limit: 25)
        } catch {
            results = []
            errorMessage = error.localizedDescription
        }
    }

    func search(_ query: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            results = try await searchProvider.search(query: query, limit: 25)
        } catch {
            results = []
            errorMessage = error.localizedDescription
        }
    }
}
