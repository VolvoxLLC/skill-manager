import SwiftUI

struct LogsView: View {
    @StateObject var viewModel: LogsViewModel

    var body: some View {
        VStack {
            TextField("Filter logs", text: $viewModel.filterText)
                .textFieldStyle(.roundedBorder)
                .padding()
            ContentUnavailableView("No logs", systemImage: "doc.text.magnifyingglass", description: Text("App activity will appear here."))
        }
    }
}
