import SkillDeckCore
import SwiftUI

struct DiscoverView: View {
    @StateObject var viewModel: DiscoverViewModel
    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            List(viewModel.results) { skill in
                VStack(alignment: .leading, spacing: 4) {
                    Text(skill.name).font(.headline)
                    Text(skill.source.location).font(.caption).foregroundStyle(.secondary)
                    if let installCount = skill.installCount {
                        Text("\(installCount) installs").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .overlay {
                if viewModel.results.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView("Search skills", systemImage: "magnifyingglass", description: Text("Find skills from skills.sh."))
                }
            }
        }
    }

    private var searchBar: some View {
        HStack {
            TextField("Search skills", text: $query)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    Task { await viewModel.search(query) }
                }
            Button("Refresh") {
                Task { await viewModel.search(query) }
            }
            .disabled(query.count < 2 || viewModel.isLoading)
        }
        .padding()
    }
}
