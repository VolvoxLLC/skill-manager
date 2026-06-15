import SwiftUI

struct UpdatesView: View {
    @ObservedObject var workspace: SkillDeckWorkspaceViewModel

    var body: some View {
        LiquidGlassPanel {
            VStack(spacing: 0) {
                HStack {
                    SkillDeckHeader(
                        title: "Updates",
                        subtitle: "Changed upstream hashes appear here before SkillDeck writes anything locally."
                    )
                    Spacer()
                    Button("Check") {
                        Task { await workspace.checkForUpdates() }
                    }
                }
                .padding(16)
                .background(.thinMaterial)

                List(workspace.availableUpdates) { update in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(update.skillName)
                                .font(.system(.headline, design: .rounded, weight: .semibold))
                            Text("Installed \(update.installedHash)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Text("Upstream \(update.upstreamHash)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("Update") {
                            Task { await workspace.updateInstalledSkill(update.installedSkillID) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.glassStroke)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 3)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .overlay {
                    if workspace.availableUpdates.isEmpty {
                        SkillDeckEmptyState(
                            title: "No updates",
                            systemImage: "arrow.clockwise",
                            description: "Update checks will appear here."
                        )
                    }
                }
            }
        }
    }
}
