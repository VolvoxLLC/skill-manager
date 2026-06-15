import AppKit
import SwiftUI

struct InstalledView: View {
    @ObservedObject var workspace: SkillDeckWorkspaceViewModel
    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            installedList
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.glassSpacing) {
            HStack {
                SkillDeckHeader(
                    title: "Installed",
                    subtitle: "Synced from user-granted agent skill folders. Grant access to scan ~/.agents, ~/.claude, ~/.codex, and ~/.copilot."
                )
                Spacer()
                Button("Grant Access…") {
                    chooseInstalledSkillsFolder()
                }
                .buttonStyle(.bordered)
                .help("Grant folder access for installed-skill scanning")
                Button {
                    Task { await workspace.syncInstalledSkills() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .help("Sync installed skills")
            }
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search installed", text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassCapsule(interactive: true)
        }
        .padding(Theme.contentPadding)
    }

    private var installedList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.glassSpacing) {
                ForEach(filteredSkills) { skill in
                    Button {
                        Task { await workspace.selectInstalledSkill(skill.id) }
                    } label: {
                        installedSkillCard(skill)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.contentPadding)
            .padding(.bottom, Theme.contentPadding)
        }
        .overlay {
            if workspace.installedSkills.isEmpty {
                SkillDeckEmptyState(
                    title: "No installed skills",
                    systemImage: "tray",
                    description: "Grant access to an enclosing folder, then sync installed agent skills."
                )
            } else if filteredSkills.isEmpty {
                SkillDeckEmptyState(
                    title: "No matching skills",
                    systemImage: "magnifyingglass",
                    description: "Try a different search."
                )
            }
        }
    }

    private var filteredSkills: [InstalledSkillViewState] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return workspace.installedSkills }
        return workspace.installedSkills.filter { skill in
            skill.name.localizedCaseInsensitiveContains(trimmedQuery)
                || skill.description.localizedCaseInsensitiveContains(trimmedQuery)
                || skill.targetDisplayName.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private func installedSkillCard(_ skill: InstalledSkillViewState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(skill.name)
                    .font(.headline)
                Spacer()
                Button {
                    do {
                        try workspace.restoreLatestBackup(for: skill.id)
                    } catch {
                        workspace.errorMessage = error.localizedDescription
                    }
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle")
                }
                .disabled(skill.latestBackup == nil)
                .buttonStyle(.plain)
                .help("Restore latest backup")
            }
            Text(skill.description)
                .font(.subheadline)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.contentPadding)
        .glassCard(interactive: true)
    }

    private func chooseInstalledSkillsFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select your home folder or another enclosing folder so SkillDeck can read installed agent skills."
        panel.prompt = "Grant Access"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await workspace.grantInstalledSkillsFolder(url) }
    }
}
