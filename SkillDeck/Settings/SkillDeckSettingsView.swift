import SwiftUI

struct SkillDeckSettingsView: View {
    @AppStorage("launchAtLoginEnabled") private var launchAtLoginEnabled = false
    @AppStorage("menuBarItemEnabled") private var menuBarItemEnabled = false
    @AppStorage("defaultLandingPage") private var defaultLandingPage = "Discover"
    @AppStorage("backgroundUpdateChecksEnabled") private var backgroundUpdateChecksEnabled = true
    @AppStorage("confirmBeforeInstalling") private var confirmBeforeInstalling = true
    @AppStorage("confirmBeforeRemoving") private var confirmBeforeRemoving = true
    @AppStorage("confirmBeforeOverwritingLocalChanges") private var confirmBeforeOverwritingLocalChanges = true
    @AppStorage("defaultInstallMode") private var defaultInstallMode = "Copy"
    @AppStorage("appearanceMode") private var appearanceMode = "System"
    @AppStorage("textSize") private var textSize = "Default"
    @AppStorage("compactModeEnabled") private var compactModeEnabled = false
    @AppStorage("skillsDisplayMode") private var skillsDisplayMode = "List"
    @AppStorage("autoUpdateTrustedSources") private var autoUpdateTrustedSources = true
    @AppStorage("sentryCrashReportingEnabled") private var sentryCrashReportingEnabled = false
    @AppStorage("amplitudeAnalyticsEnabled") private var amplitudeAnalyticsEnabled = false

    var body: some View {
        TabView {
            Form {
                Toggle("Launch at login", isOn: $launchAtLoginEnabled)
                Toggle("Show menu bar item", isOn: $menuBarItemEnabled)
                Picker("Default landing page", selection: $defaultLandingPage) {
                    ForEach(["Discover", "Installed", "Updates", "Logs"], id: \.self) { page in
                        Text(page).tag(page)
                    }
                }
                Toggle("Enable background update checks", isOn: $backgroundUpdateChecksEnabled)
                Toggle("Confirm before installing skills", isOn: $confirmBeforeInstalling)
                Toggle("Confirm before removing skills", isOn: $confirmBeforeRemoving)
                Toggle("Confirm before overwriting local changes", isOn: $confirmBeforeOverwritingLocalChanges)
            }
            .tabItem { Label("General", systemImage: "gearshape") }

            Form {
                Picker("Default install mode", selection: $defaultInstallMode) {
                    Text("Copy").tag("Copy")
                }
                Text("Copy is the only enabled install mode in this MVP. Symlink support stays disabled until the sandbox path rules are hardened.")
                    .foregroundStyle(.secondary)
            }
            .tabItem { Label("Install", systemImage: "square.and.arrow.down") }

            Form {
                Picker("Theme", selection: $appearanceMode) {
                    ForEach(["System", "Light", "Dark"], id: \.self) { mode in
                        Text(mode).tag(mode)
                    }
                }
                Picker("Text size", selection: $textSize) {
                    ForEach(["Small", "Default", "Large", "Extra Large"], id: \.self) { size in
                        Text(size).tag(size)
                    }
                }
                Toggle("Compact mode", isOn: $compactModeEnabled)
                Picker("Skills display", selection: $skillsDisplayMode) {
                    Text("List").tag("List")
                    Text("Cards").tag("Cards")
                }
                HStack {
                    Text("Accent")
                    Spacer()
                    Circle()
                        .fill(Color.systemAccent)
                        .frame(width: 16, height: 16)
                    Text("macOS default")
                        .foregroundStyle(.secondary)
                }
            }
            .tabItem { Label("Appearance", systemImage: "paintpalette") }

            Form {
                Toggle("Auto-update trusted sources", isOn: $autoUpdateTrustedSources)
                Text("Auto-updates stop when local modifications or missing folder grants are detected.")
                    .foregroundStyle(.secondary)
            }
            .tabItem { Label("Updates", systemImage: "arrow.clockwise") }

            Form {
                Toggle("Sentry crash reporting", isOn: $sentryCrashReportingEnabled)
                Toggle("Amplitude analytics", isOn: $amplitudeAnalyticsEnabled)
            }
            .tabItem { Label("Privacy", systemImage: "hand.raised") }
        }
        .padding()
        .tint(Color.systemAccent)
        .frame(width: 680, height: 500)
    }
}
