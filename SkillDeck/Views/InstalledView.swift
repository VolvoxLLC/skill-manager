import SwiftUI
import SkillDeckSources

struct InstalledView: View {
    @StateObject var viewModel: InstalledViewModel
    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            List(viewModel.filteredSkills) { skill in
                VStack(alignment: .leading, spacing: 8) {
                    Text(skill.name).font(.headline)
                    Text(skill.description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    HStack(spacing: 6) {
                        ForEach(skill.targets, id: \.self) { target in
                            Badge(label: target)
                        }
                        Spacer()
                        Button(action: { viewModel.revealInFinder(skill) }) {
                            Image(systemName: "folder")
                                .font(.caption)
                        }
                        .help("Reveal in Finder")
                    }
                    .font(.caption2)
                }
                .padding(.vertical, 4)
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.skills.isEmpty {
                    ContentUnavailableView("No installed skills", systemImage: "tray", description: Text("Installed skills will appear here."))
                } else if viewModel.filteredSkills.isEmpty {
                    ContentUnavailableView("No matching skills", systemImage: "magnifyingglass", description: Text("Try a different search."))
                }
            }
        }
        .task { await viewModel.loadInstalled() }
        .onChange(of: query) { _, newValue in
            viewModel.updateSearch(newValue)
        }
    }

    private var searchBar: some View {
        HStack {
            TextField("Search installed", text: $query)
                .textFieldStyle(.roundedBorder)
            Button("Refresh") {
                Task {
                    await viewModel.loadInstalled()
                }
            }
        }
        .padding()
    }
}

private struct Badge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.3))
            .cornerRadius(4)
    }
}
