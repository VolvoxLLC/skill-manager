import SwiftUI

private enum SidebarSelection: String, CaseIterable, Identifiable {
    case discover = "Discover"
    case installed = "Installed"
    case sources = "Sources"
    case updates = "Updates"
    case logs = "Logs"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .discover: "sparkle.magnifyingglass"
        case .installed: "tray.full"
        case .sources: "point.3.connected.trianglepath.dotted"
        case .updates: "arrow.triangle.2.circlepath"
        case .logs: "doc.text.magnifyingglass"
        case .settings: "gearshape"
        }
    }
}

struct MainWindowView: View {
    @State private var selection: SidebarSelection? = .discover
    @StateObject private var dependencies = DependencyContainer()

    var body: some View {
        NavigationSplitView {
            List(SidebarSelection.allCases, selection: $selection) { item in
                Label(LocalizedStringKey(item.rawValue), systemImage: item.systemImage)
                    .tag(item)
            }
            .listStyle(.sidebar)
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
        .tint(.systemAccent)
    }

    @ViewBuilder
    private var contentView: some View {
        switch selection {
        case .discover:
            DiscoverView(viewModel: DiscoverViewModel(
                searchProvider: dependencies.searchProvider,
                trendingProvider: dependencies.trendingProvider
            ))
        case .installed:
            InstalledView(viewModel: InstalledViewModel(scanner: dependencies.installedScanner))
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
