import Foundation
import SkillDeckSources

@MainActor
final class DependencyContainer: ObservableObject {
    let searchProvider: SkillSearchProviding
    let trendingProvider: SkillTrendingProviding
    let installedScanner: InstalledSkillScanner

    init(
        searchProvider: SkillSearchProviding = SkillsShSearchProvider(),
        trendingProvider: SkillTrendingProviding = SkillsShTrendingProvider(),
        installedScanner: InstalledSkillScanner = InstalledSkillScanner()
    ) {
        self.searchProvider = searchProvider
        self.trendingProvider = trendingProvider
        self.installedScanner = installedScanner
    }
}
