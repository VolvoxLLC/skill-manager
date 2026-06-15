import SkillDeckCore
import SwiftUI

struct SourcesView: View {
    @ObservedObject var workspace: SkillDeckWorkspaceViewModel
    @State private var sourceURLText = ""

    var body: some View {
        VStack(spacing: 0) {
            sourceForm
            sourceList
        }
    }

    private var sourceForm: some View {
        VStack(alignment: .leading, spacing: Theme.glassSpacing) {
            SkillDeckHeader(
                title: "Sources",
                subtitle: "Add a public GitHub repository and SkillDeck will scan supported SKILL.md layouts."
            )
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
                TextField("owner/repo or https://github.com/owner/repo", text: $sourceURLText)
                    .textFieldStyle(.plain)
                    .onSubmit(addSource)
                Button {
                    addSource()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .disabled(sourceURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Add source")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassCapsule(interactive: true)
        }
        .padding(Theme.contentPadding)
    }

    private var sourceList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.glassSpacing) {
                ForEach(githubSkills, id: \.summary.id) { detail in
                    Button {
                        Task { await workspace.selectSkill(detail.summary.id) }
                    } label: {
                        sourceCard(detail)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.contentPadding)
            .padding(.bottom, Theme.contentPadding)
        }
        .overlay {
            if githubSkills.isEmpty {
                SkillDeckEmptyState(
                    title: "No sources",
                    systemImage: "externaldrive.badge.plus",
                    description: "Add a public GitHub repository to scan for skills."
                )
            }
        }
    }

    private var githubSkills: [SkillDetail] {
        workspace.availableSkills.filter { $0.summary.source.kind == .github }
    }

    private func sourceCard(_ detail: SkillDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(detail.summary.name)
                .font(.headline)
            Text(detail.summary.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack {
                SkillMetricPill(text: detail.summary.source.location, systemImage: "link")
                SkillMetricPill(text: detail.relativePath, systemImage: "doc.text")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.contentPadding)
        .glassCard(interactive: true)
    }

    private func addSource() {
        let source = sourceURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return }
        sourceURLText = ""
        Task { await workspace.addGitHubSource(source) }
    }
}
