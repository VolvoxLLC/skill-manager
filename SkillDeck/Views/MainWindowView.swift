import SwiftUI

struct MainWindowView: View {
    var body: some View {
        NavigationSplitView {
            List {
                Text("Discover")
                Text("Installed")
                Text("Sources")
                Text("Updates")
                Text("Logs")
                Text("Settings")
            }
        } content: {
            Text("Select a section")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } detail: {
            Text("No skill selected")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("SkillDeck")
    }
}
