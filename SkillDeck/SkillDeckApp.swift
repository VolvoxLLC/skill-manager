import SwiftUI

@main
struct SkillDeckApp: App {
    var body: some Scene {
        WindowGroup {
            MainWindowView()
        }
        .commands {
            SkillDeckCommands()
        }

        Settings {
            SkillDeckSettingsView()
        }
    }
}
