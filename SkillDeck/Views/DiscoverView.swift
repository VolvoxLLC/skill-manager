import SkillDeckCore
import SwiftUI

struct DiscoverView: View {
    @ObservedObject var workspace: SkillDeckWorkspaceViewModel
    @State private var query = ""

    var body: some View {
        LiquidGlassPanel {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    SkillDeckHeader(
                        title: "Catalog",
                        subtitle: "Top downloaded skills appear first. Search narrows the catalog without losing source context."
                    )
                    searchBar
                }
                .padding(16)
                .background(.thinMaterial)

                List(Array(displayedSkills.enumerated()), id: \.element.id) { index, skill in
                    Button {
                        Task { await workspace.selectSkill(skill.id) }
                    } label: {
                        skillRow(skill, rank: index + 1)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 3)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .overlay {
                    if displayedSkills.isEmpty {
                        SkillDeckEmptyState(
                            title: "No catalog results",
                            systemImage: "magnifyingglass",
                            description: "SkillDeck could not load skills from skills.sh."
                        )
                    }
                }
            }
        }
    }

    private var searchBar: some View {
        HStack {
            TextField("Search skills", text: $query)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    Task { await workspace.search(query) }
                }
            Button("Refresh") {
                Task {
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        await workspace.loadInitialCatalog()
                    } else {
                        await workspace.search(query)
                    }
                }
            }
            .keyboardShortcut("r", modifiers: [.command])
        }
    }

    private var displayedSkills: [SkillSummary] {
        var summaries = workspace.searchResults.isEmpty ? workspace.catalogSkills : workspace.searchResults
        let knownIDs = Set(summaries.map(\.id))
        summaries.append(contentsOf: workspace.availableSkills.map(\.summary).filter { !knownIDs.contains($0.id) })
        return summaries
    }

    private func skillRow(_ skill: SkillSummary, rank: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(rank.formatted())
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(.thinMaterial, in: Circle())

            VStack(alignment: .leading, spacing: 7) {
                Text(skill.name)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Text(skill.description.isEmpty ? skill.source.location : skill.description)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack {
                    SkillMetricPill(text: skill.source.location, systemImage: "link")
                    if let installCount = skill.installCount {
                        SkillMetricPill(text: "\(installCount.formatted()) installs", systemImage: "arrow.down.circle")
                    }
                }
            }
            Spacer(minLength: 8)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.glassStroke)
        }
    }
}
