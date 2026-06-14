import Foundation
import SkillDeckSources

@MainActor
final class DependencyContainer: ObservableObject {
    let searchProvider: SkillSearchProviding

    init(searchProvider: SkillSearchProviding = SkillsShSearchProvider()) {
        self.searchProvider = searchProvider
    }
}
