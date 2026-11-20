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
            CommandGroup(before: .toolbar) {
                LayoutMenu()
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

/// View menu items that switch the main window layout (Cmd+1 to Cmd+3).
private struct LayoutMenu: View {
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        ForEach(Array(AppLayout.allCases.enumerated()), id: \.element.id) { index, layout in
            Button {
                settings.layout = layout
            } label: {
                if settings.layout == layout {
                    Label(layout.label, systemImage: "checkmark")
                } else {
                    Text(layout.label)
                }
            }
            .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
        }
        Divider()
    }
}
