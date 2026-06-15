import SwiftUI

struct SkillInspectorView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "square.dashed")
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text("No skill selected")
                .font(.headline)
            Text("Select a skill to preview metadata, installation targets, and update state.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.contentPadding)
        .glassCard()
        .padding(Theme.contentPadding)
    }
}
