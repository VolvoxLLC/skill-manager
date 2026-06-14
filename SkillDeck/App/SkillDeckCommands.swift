import SwiftUI

struct SkillDeckCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Refresh") {}
                .keyboardShortcut("r", modifiers: [.command])
            Button("Update All") {}
                .keyboardShortcut("u", modifiers: [.command, .shift])
        }
    }
}
