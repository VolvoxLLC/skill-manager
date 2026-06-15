import SkillDeckCore
import SwiftUI

struct DiscoverView: View {
    @StateObject var viewModel: DiscoverViewModel
    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            resultsList
        }
        .task { await viewModel.loadTrending() }
    }

    private var resultsList: some View {
        ScrollView {
            GlassEffectContainer(spacing: Theme.glassSpacing) {
                LazyVStack(spacing: Theme.glassSpacing) {
                    ForEach(viewModel.results) { skill in
                        skillCard(skill)
                            .onAppear { viewModel.loadMoreIfNeeded(currentItem: skill) }
                    }
                }
                .padding(.horizontal, Theme.contentPadding)
                .padding(.bottom, Theme.contentPadding)
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.results.isEmpty {
                ProgressView()
            } else if viewModel.results.isEmpty {
                ContentUnavailableView {
                    Label("Search skills", systemImage: "sparkle.magnifyingglass")
                } description: {
                    Text(viewModel.errorMessage ?? "Find skills from skills.sh.")
                }
            }
        }
    }

    private func skillCard(_ skill: SkillSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(skill.name).font(.headline)
                Spacer()
                if let installCount = skill.installCount {
                    Label("\(installCount)", systemImage: "arrow.down.circle")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tint)
                }
            }
            if !skill.description.isEmpty {
                Text(skill.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text(skill.source.location)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.contentPadding)
        .glassCard(interactive: true)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search skills", text: $query)
                .textFieldStyle(.plain)
                .onSubmit { Task { await viewModel.search(query) } }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(Theme.contentPadding)
    }
}
