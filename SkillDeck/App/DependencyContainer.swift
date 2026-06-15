import Foundation
import SkillDeckSources

@MainActor
final class DependencyContainer: ObservableObject {
    let searchProvider: SkillSearchProviding
    let trendingProvider: SkillTrendingProviding

    init(
        searchProvider: SkillSearchProviding = SkillsShSearchProvider(),
        trendingProvider: SkillTrendingProviding = SkillsShTrendingProvider()
    ) {
        self.searchProvider = searchProvider
        self.trendingProvider = trendingProvider
    }
}
