import SkillDeckServices
import SwiftUI

struct InstallPreviewSheet: View {
    let preview: InstallPreview
    let onCancel: () -> Void
    let onInstall: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Install \(preview.skillName)")
                .font(.title2)
            Text("Mode: Copy")
                .foregroundStyle(.secondary)
            List(preview.destinations, id: \.path) { destination in
                Text(destination.path)
                    .font(.system(.body, design: .monospaced))
            }
            HStack {
                Button("Cancel", action: onCancel)
                Spacer()
                Button("Install", action: onInstall)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 560, height: 360)
    }
}
