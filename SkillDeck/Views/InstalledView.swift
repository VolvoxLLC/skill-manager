import SwiftUI

struct InstalledView: View {
    @StateObject var viewModel: InstalledViewModel

    var body: some View {
        ContentUnavailableView("No installed skills", systemImage: "tray", description: Text("Installed skills will appear here."))
    }
}
