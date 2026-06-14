import Foundation

@MainActor
final class InstalledViewModel: ObservableObject {
    @Published var searchText = ""
}
