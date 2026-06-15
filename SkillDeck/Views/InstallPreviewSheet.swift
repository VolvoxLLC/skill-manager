import SkillDeckServices
import SwiftUI

struct InstallPreviewSheet: View {
    let preview: InstallPreview
    let onCancel: () -> Void
    let onInstall: () -> Void

    var body: some View {
        LiquidGlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                SkillDeckHeader(title: "Install \(preview.skillName)", subtitle: "Review the copy destinations before SkillDeck writes files.")
                SkillMetricPill(text: "Copy mode", systemImage: "doc.on.doc")
                List(preview.destinations, id: \.path) { destination in
                    Text(destination.path)
                        .font(.system(.body, design: .monospaced))
                }
                .scrollContentBackground(.hidden)
                HStack {
                    Button("Cancel", action: onCancel)
                    Spacer()
                    Button("Install", action: onInstall)
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .tint(Color.systemAccent)
        .frame(width: 560, height: 360)
    }
}
