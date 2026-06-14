import Foundation

@MainActor
final class LogsViewModel: ObservableObject {
    @Published var filterText = ""
}
