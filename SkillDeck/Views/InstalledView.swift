import SwiftUI

struct InstalledView: View {
    @ObservedObject var workspace: SkillDeckWorkspaceViewModel

    var body: some View {
        LiquidGlassPanel {
            VStack(spacing: 0) {
                HStack {
                    SkillDeckHeader(
                        title: "Installed",
                        subtitle: "Synced from ~/.agents/skills, ~/.claude/skills, ~/.codex/skills, and ~/.copilot/skills."
                    )
                    Spacer()
                    Button("Sync") {
                        Task { await workspace.syncInstalledSkills() }
                    }
                }
                .padding(16)
                .background(.thinMaterial)

                List(workspace.installedSkills) { skill in
                    installedSkillRow(skill)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task { await workspace.selectInstalledSkill(skill.id) }
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 3)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .overlay {
                    if workspace.installedSkills.isEmpty {
                        SkillDeckEmptyState(
                            title: "No installed skills",
                            systemImage: "tray",
                            description: "Local agent skill folders are empty or unavailable."
                        )
                    }
                }
            }
        }
    }

    private func installedSkillRow(_ skill: InstalledSkillViewState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(skill.name)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Spacer()
                Button("Restore") {
                    try? workspace.restoreLatestBackup(for: skill.id)
                }
                .disabled(skill.latestBackup == nil)
                .buttonStyle(.bordered)
            }
            Text(skill.description)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack {
                SkillMetricPill(text: skill.targetDisplayName, systemImage: "terminal")
                SkillMetricPill(text: skill.destination.deletingLastPathComponent().path, systemImage: "folder")
            }
            Text(skill.installedHash)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.glassStroke)
        }
    }
}
