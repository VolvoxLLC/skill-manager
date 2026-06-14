import Foundation

@MainActor
final class SourcesViewModel: ObservableObject {
    @Published var sourceURLText = ""
}
