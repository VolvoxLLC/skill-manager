import SwiftUI

struct SourcesView: View {
    @StateObject var viewModel: SourcesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.glassSpacing) {
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
                TextField("GitHub repository URL", text: $viewModel.sourceURLText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.regular.interactive(), in: .capsule)

            Button {
            } label: {
                Label("Add Source", systemImage: "plus")
            }
            .buttonStyle(.glassProminent)
            .disabled(viewModel.sourceURLText.isEmpty)

            Spacer()
        }
        .padding(Theme.contentPadding)
    }
}
