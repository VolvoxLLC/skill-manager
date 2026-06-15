import AppKit
import SkillDeckCore
import SwiftUI

struct SkillInspectorView: View {
    @ObservedObject var workspace: SkillDeckWorkspaceViewModel

    @ViewBuilder
    var body: some View {
        if let skill = workspace.selectedSkill {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.glassSpacing) {
                    header(for: skill)
                        .padding(Theme.contentPadding)
                        .glassCard()
                    installControls
                        .padding(Theme.contentPadding)
                        .glassCard()
                    metadata(for: skill)
                        .padding(Theme.contentPadding)
                        .glassCard()
                    skillPreview(skill.skillMarkdown)
                        .padding(Theme.contentPadding)
                        .glassCard()
                }
                .padding(Theme.contentPadding)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "square.dashed")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                Text("No skill selected")
                    .font(.headline)
                Text("Select a skill to preview metadata, installation targets, and update state.")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.contentPadding)
            .glassCard()
            .padding(Theme.contentPadding)
        }
    }

    private func header(for skill: SkillDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(skill.summary.name)
                .font(.title2.weight(.semibold))
            Text(skill.summary.description)
                .foregroundStyle(.secondary)
            HStack {
                SkillMetricPill(text: skill.summary.source.location, systemImage: "link")
                if let sourceCommit = skill.sourceCommit {
                    SkillMetricPill(text: sourceCommit, systemImage: "number")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var installControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Install")
                .font(.headline)

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
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func skillPreview(_ markdown: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SKILL.md")
                .font(.headline)
            Text(markdown)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chooseInstallFolder(kind: AgentTargetKind, displayName: String) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Grant Access"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let installFolder = validatedInstallFolder(url, kind: kind) else { return }
        workspace.grantInstallFolder(installFolder, kind: kind, displayName: displayName)
    }

    private func validatedInstallFolder(_ url: URL, kind: AgentTargetKind) -> URL? {
        switch kind {
        case .codex:
            if url.lastPathComponent == "skills", url.deletingLastPathComponent().lastPathComponent == ".codex" {
                return url
            }
            if url.lastPathComponent == ".codex" {
                return url.appendingPathComponent("skills", isDirectory: true)
            }
            workspace.errorMessage = "Select the Codex skills folder (~/.codex/skills) or its ~/.codex parent."
            return nil
        default:
            return url
        }
    }
}
