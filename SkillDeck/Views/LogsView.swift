import SwiftUI

struct LogsView: View {
    @StateObject var viewModel: LogsViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(.secondary)
                TextField("Filter logs", text: $viewModel.filterText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.regular.interactive(), in: .capsule)
            .padding(Theme.contentPadding)

            ContentUnavailableView("No logs", systemImage: "doc.text.magnifyingglass", description: Text("App activity will appear here."))
        }
    }
}
