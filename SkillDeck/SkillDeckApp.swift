import SwiftUI

@main
struct SkillDeckApp: App {
    var body: some Scene {
        WindowGroup {
            MainWindowView()
        }

        Settings {
            Text("Settings")
                .padding()
        }
    }
}
