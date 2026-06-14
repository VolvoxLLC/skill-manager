import SwiftUI

struct SkillInspectorView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No skill selected")
                .font(.headline)
            Text("Select a skill to preview metadata, installation targets, and update state.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }
}
