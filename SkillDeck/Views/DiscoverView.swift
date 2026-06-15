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
                .onAppear {
                    viewModel.loadMoreIfNeeded(currentItem: skill)
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.results.isEmpty {
                    ContentUnavailableView("Search skills", systemImage: "magnifyingglass", description: Text("Find skills from skills.sh."))
                }
            }
        }
        .task { await viewModel.loadTrending() }
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
