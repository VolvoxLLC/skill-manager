import SwiftUI

struct SourcesView: View {
    @ObservedObject var workspace: SkillDeckWorkspaceViewModel
    @State private var sourceURLText = ""

    var body: some View {
        LiquidGlassPanel {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    SkillDeckHeader(
                        title: "Sources",
                        subtitle: "Add a public GitHub repository and SkillDeck will scan supported SKILL.md layouts."
                    )
                    HStack {
                        TextField("owner/repo or https://github.com/owner/repo", text: $sourceURLText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(addSource)
                        Button("Add", action: addSource)
                            .disabled(sourceURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(16)
                .background(.thinMaterial)

                List(workspace.availableSkills.filter { $0.summary.source.kind == .github }, id: \.summary.id) { detail in
                    Button {
                        Task { await workspace.selectSkill(detail.summary.id) }
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(detail.summary.name)
                                .font(.system(.headline, design: .rounded, weight: .semibold))
                            Text(detail.summary.description)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            HStack {
                                SkillMetricPill(text: detail.summary.source.location, systemImage: "link")
                                SkillMetricPill(text: detail.relativePath, systemImage: "doc.text")
                            }
                        }
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.glassStroke)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 3)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .overlay {
                    if workspace.availableSkills.filter({ $0.summary.source.kind == .github }).isEmpty {
                        SkillDeckEmptyState(
                            title: "No sources",
                            systemImage: "externaldrive.badge.plus",
                            description: "Add a public GitHub repository to scan for skills."
                        )
                    }
                }
            }
        }
    }

    private func addSource() {
        let source = sourceURLText
        Task { await workspace.addGitHubSource(source) }
        sourceURLText = ""
    }
}
