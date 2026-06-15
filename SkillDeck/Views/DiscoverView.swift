import SkillDeckCore
import SwiftUI

struct DiscoverView: View {
    @ObservedObject var workspace: SkillDeckWorkspaceViewModel
    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            resultsList
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search skills", text: $query)
                .textFieldStyle(.plain)
                .onSubmit { Task { await workspace.search(query) } }
            if !query.isEmpty {
                Button {
                    query = ""
                    Task { await workspace.loadInitialCatalog() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Clear search")
            }
            Button {
                Task {
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        await workspace.loadInitialCatalog()
                    } else {
                        await workspace.search(query)
                    }
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Refresh catalog")
            .keyboardShortcut("r", modifiers: [.command])
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassCapsule(interactive: true)
        .padding(Theme.contentPadding)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.glassSpacing) {
                ForEach(Array(displayedSkills.enumerated()), id: \.element.id) { index, skill in
                    Button {
                        Task { await workspace.selectSkill(skill.id) }
                    } label: {
                        skillCard(skill, rank: index + 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.contentPadding)
            .padding(.bottom, Theme.contentPadding)
        }
        .overlay {
            if displayedSkills.isEmpty {
                SkillDeckEmptyState(
                    title: "No catalog results",
                    systemImage: "sparkle.magnifyingglass",
                    description: workspace.errorMessage ?? "SkillDeck could not load skills from skills.sh."
                )
            }
        }
    }

    private var displayedSkills: [SkillSummary] {
        var summaries = workspace.searchResults.isEmpty ? workspace.catalogSkills : workspace.searchResults
        let knownIDs = Set(summaries.map(\.id))
        summaries.append(contentsOf: workspace.availableSkills.map(\.summary).filter { !knownIDs.contains($0.id) })
        return summaries
    }

    private func skillCard(_ skill: SkillSummary, rank: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(rank.formatted())
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(.thinMaterial, in: Circle())

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(skill.name)
                        .font(.headline)
                    Spacer()
                    if let installCount = skill.installCount {
                        Label(installCount.formatted(), systemImage: "arrow.down.circle")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.tint)
                    }
                }
                Text(skill.description.isEmpty ? skill.source.location : skill.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                SkillMetricPill(text: skill.source.location, systemImage: "link")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.contentPadding)
        .glassCard(interactive: true)
    }
}
