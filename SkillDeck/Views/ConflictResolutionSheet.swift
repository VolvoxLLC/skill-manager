import SwiftUI

struct ConflictResolutionSheet: View {
    let path: String
    let keepLocal: () -> Void
    let backupAndOverwrite: () -> Void

    var body: some View {
        LiquidGlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                SkillDeckHeader(title: "Local changes detected", subtitle: "SkillDeck will not overwrite this file without creating a backup first.")
                Text(path)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                HStack {
                    Button("Keep Local", action: keepLocal)
                    Spacer()
                    Button("Back Up and Overwrite", action: backupAndOverwrite)
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
