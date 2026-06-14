import SwiftUI

private enum SidebarSelection: String, CaseIterable, Identifiable {
    case discover = "Discover"
    case installed = "Installed"
    case sources = "Sources"
    case updates = "Updates"
    case logs = "Logs"
    case settings = "Settings"

    var id: String { rawValue }
}

struct MainWindowView: View {
    @State private var selection: SidebarSelection? = .discover
    @StateObject private var dependencies = DependencyContainer()

    var body: some View {
        NavigationSplitView {
            List(SidebarSelection.allCases, selection: $selection) { item in
                Text(LocalizedStringKey(item.rawValue))
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } content: {
            contentView
                .frame(minWidth: 420)
        } detail: {
            SkillInspectorView()
                .frame(minWidth: 320)
        }
        .environmentObject(dependencies)
        .navigationTitle("SkillDeck")
    }

    @ViewBuilder
    private var contentView: some View {
        switch selection {
        case .discover:
            DiscoverView(viewModel: DiscoverViewModel(searchProvider: dependencies.searchProvider))
        case .installed:
            InstalledView(viewModel: InstalledViewModel())
        case .sources:
            SourcesView(viewModel: SourcesViewModel())
        case .updates:
            UpdatesView(viewModel: UpdatesViewModel())
        case .logs:
            LogsView(viewModel: LogsViewModel())
        case .settings:
            Text("Open Settings from the app menu.")
                .foregroundStyle(.secondary)
        case nil:
            Text("Select a section.")
                .foregroundStyle(.secondary)
        }
    }
}
