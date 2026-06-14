import Foundation

@MainActor
final class UpdatesViewModel: ObservableObject {
    @Published var isCheckingForUpdates = false
}
