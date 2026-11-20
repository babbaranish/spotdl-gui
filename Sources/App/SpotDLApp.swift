import SwiftUI

@main
struct SpotDLApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var dl = Downloader.shared

    var body: some Scene {
        Window("spotDL", id: "main") {
            ContentView()
                .environmentObject(dl)
                .tint(.green)
        }
        .defaultSize(width: 760, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .newItem) {
                Button("Sync All Playlists") { dl.syncAll() }
            }
            CommandGroup(after: .appSettings) {
                CheckSpotDLUpdateButton()
            }
        }

        Settings {
            SettingsView()
                .environmentObject(dl)
                .tint(.green)
        }
    }
}

/// Re-reads the spotDL version and opens Settings, where the version and the Update button are.
private struct CheckSpotDLUpdateButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Check for spotDL Update") {
            ToolStatus.shared.refresh(spotdlPath: Downloader.shared.spotdlPath)
            openSettings()
        }
    }
}
