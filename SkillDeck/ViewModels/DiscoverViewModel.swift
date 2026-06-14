import Foundation
import SkillDeckCore
import SkillDeckSources

@MainActor
final class DiscoverViewModel: ObservableObject {
    @Published private(set) var results: [SkillSummary] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let searchProvider: SkillSearchProviding

    init(searchProvider: SkillSearchProviding) {
        self.searchProvider = searchProvider
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
