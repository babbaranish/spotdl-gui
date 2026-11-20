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
        }
    }
}
