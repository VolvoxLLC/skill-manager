import AppKit
import SkillDeckCore
import SwiftUI

struct SkillInspectorView: View {
    @ObservedObject var workspace: SkillDeckWorkspaceViewModel

    @ViewBuilder
    var body: some View {
        if let skill = workspace.selectedSkill {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LiquidGlassPanel {
                        header(for: skill)
                            .padding(16)
                    }
                    LiquidGlassPanel {
                        installControls
                            .padding(16)
                    }
                    LiquidGlassPanel {
                        metadata(for: skill)
                            .padding(16)
                    }
                    LiquidGlassPanel {
                        skillPreview(skill.skillMarkdown)
                            .padding(16)
                    }
                }
            }
        } else {
            LiquidGlassPanel {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.systemAccent)
                    Text("No skill selected")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                    Text("Click any catalog, source, or installed skill to inspect metadata, SKILL.md content, and install state here.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(18)
            }
        }
    }

    private func header(for skill: SkillDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(skill.summary.name)
                .font(.system(.title2, design: .rounded, weight: .semibold))
            Text(skill.summary.description)
                .foregroundStyle(.secondary)
            HStack {
                SkillMetricPill(text: skill.summary.source.location, systemImage: "link")
                if let sourceCommit = skill.sourceCommit {
                    SkillMetricPill(text: sourceCommit, systemImage: "number")
                }
            }
        }
    }

    private var installControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Install")
                .font(.system(.headline, design: .rounded, weight: .semibold))

            if workspace.installTargets.isEmpty {
                Text("Grant a target folder before installing.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(workspace.installTargets) { target in
                    Label(target.installPath.path, systemImage: "folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button("Grant Codex Folder") {
                    chooseInstallFolder(kind: .codex, displayName: "Codex")
                }
                .buttonStyle(.bordered)
                Button("Preview Install") {
                    Task { await workspace.previewSelectedSkillForInstall() }
                }
                .disabled(workspace.selectedSkill == nil || workspace.installTargets.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func metadata(for skill: SkillDetail) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                Text("Mode").foregroundStyle(.secondary)
                Text("Copy")
            }
            GridRow {
                Text("Path").foregroundStyle(.secondary)
                Text(skill.relativePath)
                    .font(.system(.body, design: .monospaced))
            }
            GridRow {
                Text("Hash").foregroundStyle(.secondary)
                Text(skill.contentHash)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
            }
        }
    }

    private func skillPreview(_ markdown: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SKILL.md")
                .font(.system(.headline, design: .rounded, weight: .semibold))
            Text(markdown)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func chooseInstallFolder(kind: AgentTargetKind, displayName: String) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Grant Access"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        workspace.grantInstallFolder(url, kind: kind, displayName: displayName)
    }
}
