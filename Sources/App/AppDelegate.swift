import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { true }

    /// Links dropped on the Dock icon or opened with the app.
    @MainActor
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "http" || url.scheme == "https" {
            Downloader.shared.add(url.absoluteString)
        }
    }

    @MainActor
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let running = Downloader.shared.activeCount
        guard running > 0 else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Downloads are still running"
        alert.informativeText = "\(running) download(s) will stop if you quit. Songs already finished stay saved."
        alert.addButton(withTitle: "Keep Downloading")
        alert.addButton(withTitle: "Quit")
        // Jobs are not cancelled here: applicationWillTerminate saves them as interrupted so they can be retried.
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }

    @MainActor
    func applicationWillTerminate(_ notification: Notification) {
        Downloader.shared.saveHistory()
        for job in Downloader.shared.jobs { job.process?.terminate() }
    }
}
