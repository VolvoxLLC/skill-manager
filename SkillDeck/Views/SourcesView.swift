import SwiftUI

struct SourcesView: View {
    @StateObject var viewModel: SourcesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("GitHub repository URL", text: $viewModel.sourceURLText)
                .textFieldStyle(.roundedBorder)
            Button("Add Source") {}
                .disabled(viewModel.sourceURLText.isEmpty)
            Spacer()
        }
        .padding()
    }
}
