import AppKit
import SwiftUI

/// Renders every layout with sample jobs to PNG files, so the UI can be checked without screen recording.
/// Runs only when SPOTDL_GUI_SNAPSHOT is set to an output folder. It never starts spotDL and never saves history.
@MainActor
enum DebugSnapshot {
    private static let appearances: [(name: NSAppearance.Name, suffix: String)] = [
        (.darkAqua, "dark"),
        (.aqua, "light"),
    ]

    static func runIfRequested() {
        guard let path = ProcessInfo.processInfo.environment["SPOTDL_GUI_SNAPSHOT"], !path.isEmpty else { return }
        let outDir = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        // In memory only: nothing here calls add, retry or sync, so no process starts and nothing is saved.
        Downloader.shared.jobs = sampleJobs()

        Task { @MainActor in
            var failed = false
            for layout in AppLayout.allCases {
                for appearance in appearances {
                    let window = makeWindow(layout: layout, appearance: appearance.name)
                    window.orderFrontRegardless()
                    // Let SwiftUI lay out and draw. Task.sleep keeps the main run loop running.
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    let file = outDir.appendingPathComponent("\(layout.rawValue)-\(appearance.suffix).png")
                    if !writePNG(of: window, to: file) { failed = true }
                    window.close()
                }
            }
            // Exit without applicationWillTerminate, so history is never written.
            exit(failed ? 1 : 0)
        }
    }

    private static func makeWindow(layout: AppLayout, appearance: NSAppearance.Name) -> NSWindow {
        // Off-screen origin so the snapshot windows never cover the screen.
        let window = NSWindow(
            contentRect: NSRect(x: -20_000, y: -20_000, width: 900, height: 620),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: appearance)
        window.contentView = NSHostingView(
            rootView: ContentView(layoutOverride: layout)
                .environmentObject(Downloader.shared)
                .tint(.green)
        )
        return window
    }

    private static func writePNG(of window: NSWindow, to url: URL) -> Bool {
        guard let view = window.contentView else { return false }
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            fputs("DebugSnapshot: no bitmap for \(url.lastPathComponent)\n", stderr)
            return false
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            fputs("DebugSnapshot: no PNG for \(url.lastPathComponent)\n", stderr)
            return false
        }
        do {
            try data.write(to: url)
            return true
        } catch {
            fputs("DebugSnapshot: cannot write \(url.path): \(error.localizedDescription)\n", stderr)
            return false
        }
    }

    /// Jobs shaped like the mockup, built from the same spotDL output lines the app parses.
    private static func sampleJobs() -> [Job] {
        let outDir = Downloader.shared.outputDir
        let options = SettingsStore.shared.options

        func job(_ query: String, _ lines: [String] = [], cancelled: Bool = false, exitCode: Int32? = nil) -> Job {
            let job = Job(query: query, options: options, outputDir: outDir)
            if !lines.isEmpty {
                job.ingest(Data((lines.joined(separator: "\n") + "\n").utf8))
            }
            if cancelled { job.cancelRequested = true }
            if let exitCode { job.finish(exitCode: exitCode) }
            return job
        }

        func downloaded(_ songs: [String]) -> [String] {
            songs.enumerated().map { i, song in
                "Downloaded \"\(song)\": https://music.youtube.com/watch?v=sample\(i)"
            }
        }

        let roadTripSongs = [
            "Khruangbin - Maria También", "Tame Impala - Borderline", "Men I Trust - Show Me How",
            "Mac DeMarco - Chamber of Reflection", "Thundercat - Show You the Way", "Real Estate - Talking Backwards",
            "Glass Animals - Heat Waves", "Fleetwood Mac - Dreams", "Phoenix - 1901", "Local Natives - Sun Hands",
            "Cigarettes After Sex - Apocalypse", "Beach House - Space Song",
        ]

        // Downloading: 12 of 32 done, one song in progress.
        let roadTrip = job("https://open.spotify.com/playlist/3RoadTripMix", [
            "Processing query: https://open.spotify.com/playlist/3RoadTripMix",
            "Found 32 songs in Road Trip Mix (Playlist)",
        ] + downloaded(roadTripSongs) + [
            "Hot Chip - Over and Over: Downloading",
        ])

        // Waiting: fetched the name, nothing downloaded yet.
        let blueRoom = job("https://open.spotify.com/album/1BlueRoomAlbum", [
            "Found 11 songs in Blue Room (Album)",
        ])

        let morningRun = job("https://open.spotify.com/playlist/4MorningRunList", [
            "Found 24 songs in Morning Run (Playlist)",
        ])
        let quietHours = job("https://open.spotify.com/album/6QuietHoursAlbum", [
            "Found 8 songs in Quiet Hours (Album)",
        ])

        // Done: a single song.
        let single = job("https://open.spotify.com/track/5MariaSingle", [
            "Processing query: https://open.spotify.com/track/5MariaSingle",
        ] + downloaded(["Khruangbin - Maria También"]), exitCode: 0)

        // Done with one failed song: shows under Needs attention.
        let summer = job("https://open.spotify.com/album/2SummerTapesAlbum", [
            "Processing query: https://open.spotify.com/album/2SummerTapesAlbum",
            "Found 10 songs in Summer Tapes (Album)",
        ] + downloaded(Array(roadTripSongs.prefix(9))) + [
            "LookupError: No results found for song: Sun Parlor - Lantern Wave",
        ], exitCode: 0)

        // Cancelled after three songs.
        let cancelled = job("https://open.spotify.com/album/3LateNightAlbum", [
            "Processing query: https://open.spotify.com/album/3LateNightAlbum",
            "Found 12 songs in Late Night Drive (Album)",
        ] + downloaded(Array(roadTripSongs.prefix(3))), cancelled: true, exitCode: 15)

        return [roadTrip, blueRoom, morningRun, quietHours, single, summer, cancelled]
    }
}
