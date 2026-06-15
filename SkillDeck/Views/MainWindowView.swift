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
        case .discover: "magnifyingglass"
        case .installed: "tray.full"
        case .sources: "point.3.connected.trianglepath.dotted"
        case .updates: "arrow.triangle.2.circlepath"
        case .logs: "doc.text.magnifyingglass"
        case .settings: "slider.horizontal.3"
        }
    }
}

struct MainWindowView: View {
    @State private var selection: SidebarSelection? = .discover
    @StateObject private var workspace = SkillDeckWorkspaceViewModel()
    @AppStorage("defaultLandingPage") private var defaultLandingPage = "Discover"
    @AppStorage("appearanceMode") private var appearanceMode = "System"
    @AppStorage("compactModeEnabled") private var compactModeEnabled = false
    @State private var didApplyDefaultLandingPage = false

    var body: some View {
        NavigationSplitView {
            List(SidebarSelection.allCases, selection: $selection) { item in
                Label(LocalizedStringKey(item.rawValue), systemImage: item.systemImage)
                    .tag(item)
            }
            .scrollContentBackground(.hidden)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } content: {
            contentView
                .frame(minWidth: 420)
                .padding(14)
        } detail: {
            SkillInspectorView(workspace: workspace)
                .frame(minWidth: 320)
                .padding(14)
        }
        .navigationTitle("SkillDeck")
        .controlSize(compactModeEnabled ? .small : .regular)
        .preferredColorScheme(preferredColorScheme)
        .background {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color.systemAccent.opacity(0.08),
                    Color(nsColor: .controlBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .tint(Color.systemAccent)
        .task {
            if !didApplyDefaultLandingPage {
                selection = SidebarSelection(rawValue: defaultLandingPage) ?? .discover
                didApplyDefaultLandingPage = true
            }
            await workspace.bootstrap()
        }
        .sheet(isPresented: installPreviewPresented) {
            if let preview = workspace.pendingInstallPreview {
                InstallPreviewSheet(
                    preview: preview,
                    onCancel: { workspace.pendingInstallPreview = nil },
                    onInstall: {
                        Task {
                            try? await workspace.installSelectedSkill()
                        }
                    }
                )
            }
        }
        .sheet(isPresented: conflictPresented) {
            if let conflict = workspace.pendingConflict {
                ConflictResolutionSheet(
                    path: conflict.path,
                    keepLocal: {
                        Task { await workspace.keepLocalConflict() }
                    },
                    backupAndOverwrite: {
                        Task { try? await workspace.backupAndOverwriteConflict() }
                    }
                )
            }
        }
        .alert(
            "SkillDeck",
            isPresented: Binding(
                get: { workspace.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        workspace.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {}
        } message: {
            Text(workspace.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch selection {
        case .discover:
            DiscoverView(workspace: workspace)
        case .installed:
            InstalledView(workspace: workspace)
        case .sources:
            SourcesView(workspace: workspace)
        case .updates:
            UpdatesView(workspace: workspace)
        case .logs:
            LogsView(workspace: workspace)
        case .settings:
            LiquidGlassPanel {
                SkillDeckSettingsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case nil:
            Text("Select a section.")
                .foregroundStyle(.secondary)
        }
    }

    private var installPreviewPresented: Binding<Bool> {
        Binding(
            get: { workspace.pendingInstallPreview != nil },
            set: { isPresented in
                if !isPresented {
                    workspace.pendingInstallPreview = nil
                }
            }
        )
    }

    private var conflictPresented: Binding<Bool> {
        Binding(
            get: { workspace.pendingConflict != nil },
            set: { isPresented in
                if !isPresented {
                    workspace.pendingConflict = nil
                }
            }
        )
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "Light": .light
        case "Dark": .dark
        default: nil
        }
    }
}
