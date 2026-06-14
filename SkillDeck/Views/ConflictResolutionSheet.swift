import SwiftUI

struct ConflictResolutionSheet: View {
    let path: String
    let keepLocal: () -> Void
    let backupAndOverwrite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Local changes detected")
                .font(.title2)
            Text(path)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
            Text("SkillDeck will not overwrite this file unless you choose to create a backup first.")
            HStack {
                Button("Keep Local", action: keepLocal)
                Spacer()
                Button("Back Up and Overwrite", action: backupAndOverwrite)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 520)
    }
}
