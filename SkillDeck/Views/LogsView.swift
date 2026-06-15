import SkillDeckServices
import SwiftUI

struct LogsView: View {
    @ObservedObject var workspace: SkillDeckWorkspaceViewModel
    @State private var filterText = ""

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            logList
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(.secondary)
            TextField("Filter logs", text: $filterText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassCapsule(interactive: true)
        .padding(Theme.contentPadding)
    }

    private var logList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.glassSpacing) {
                ForEach(filteredLogs) { entry in
                    logCard(entry)
                }
            }
            .padding(.horizontal, Theme.contentPadding)
            .padding(.bottom, Theme.contentPadding)
        }
        .overlay {
            if filteredLogs.isEmpty {
                SkillDeckEmptyState(
                    title: "No logs",
                    systemImage: "doc.text.magnifyingglass",
                    description: "App activity will appear here."
                )
            }
        }
    }

    private var filteredLogs: [AppLogEntry] {
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return workspace.logs }
        return workspace.logs.filter { entry in
            entry.category.localizedCaseInsensitiveContains(query)
                || entry.level.localizedCaseInsensitiveContains(query)
                || entry.message.localizedCaseInsensitiveContains(query)
        }
    }

    private func logCard(_ entry: AppLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.category)
                    .font(.headline)
                SkillMetricPill(text: entry.level)
                Spacer()
                Text(entry.createdAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(entry.message)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.contentPadding)
        .glassCard()
    }
}
