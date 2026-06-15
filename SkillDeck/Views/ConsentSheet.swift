import SwiftUI

struct ConsentSheet: View {
    @Binding var sentryEnabled: Bool
    @Binding var amplitudeEnabled: Bool
    let onContinue: () -> Void

    var body: some View {
        LiquidGlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                SkillDeckHeader(title: "Privacy", subtitle: "Telemetry stays off until you explicitly opt in.")
                Toggle("Enable crash reporting with Sentry", isOn: $sentryEnabled)
                Toggle("Enable anonymous product analytics with Amplitude", isOn: $amplitudeEnabled)
                Text("SkillDeck never sends skill contents, private repository URLs, or raw local file paths.")
                    .foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("Continue", action: onContinue)
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .tint(Color.systemAccent)
        .frame(width: 520)
    }
}
