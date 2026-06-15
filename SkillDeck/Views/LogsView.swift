import SkillDeckServices
import SwiftUI

struct LogsView: View {
    @ObservedObject var workspace: SkillDeckWorkspaceViewModel
    @State private var filterText = ""

    var body: some View {
        LiquidGlassPanel {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    SkillDeckHeader(
                        title: "Logs",
                        subtitle: "Searchable local activity with path redaction."
                    )
                    TextField("Filter logs", text: $filterText)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(16)
                .background(.thinMaterial)

                List(filteredLogs) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(entry.category)
                                .font(.system(.headline, design: .rounded, weight: .semibold))
                            SkillMetricPill(text: entry.level)
                            Spacer()
                            Text(entry.createdAt, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(entry.message)
                            .foregroundStyle(.secondary)
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
                    if filteredLogs.isEmpty {
                        SkillDeckEmptyState(
                            title: "No logs",
                            systemImage: "doc.text.magnifyingglass",
                            description: "App activity will appear here."
                        )
                    }
                }
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
}
