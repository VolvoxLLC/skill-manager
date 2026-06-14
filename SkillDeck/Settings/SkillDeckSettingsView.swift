import SwiftUI

struct SkillDeckSettingsView: View {
    var body: some View {
        TabView {
            Form {
                Toggle("Enable background update checks", isOn: .constant(true))
                Toggle("Confirm before installing skills", isOn: .constant(true))
            }
            .tabItem { Label("General", systemImage: "gearshape") }

            Form {
                Toggle("Auto-update trusted sources", isOn: .constant(true))
                Text("Auto-updates stop when local modifications or missing folder grants are detected.")
                    .foregroundStyle(.secondary)
            }
            .tabItem { Label("Updates", systemImage: "arrow.clockwise") }

            Form {
                Toggle("Sentry crash reporting", isOn: .constant(false))
                Toggle("Amplitude analytics", isOn: .constant(false))
            }
            .tabItem { Label("Privacy", systemImage: "hand.raised") }
        }
        .padding()
        .frame(width: 620, height: 420)
    }
}
