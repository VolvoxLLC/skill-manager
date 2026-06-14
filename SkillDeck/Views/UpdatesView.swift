import SwiftUI

struct UpdatesView: View {
    @StateObject var viewModel: UpdatesViewModel

    var body: some View {
        ContentUnavailableView("No updates", systemImage: "arrow.clockwise", description: Text("Update checks will appear here."))
    }
}
