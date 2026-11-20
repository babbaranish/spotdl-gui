import AppKit

/// Adds downloaded files to the Music library by opening them with Music.app.
@MainActor
enum MusicLibrary {
    static let musicAppURL = URL(fileURLWithPath: "/System/Applications/Music.app")

    /// Formats Music can import. FLAC, OGG and Opus files are left out.
    static let importableExtensions: Set<String> = ["mp3", "m4a", "wav", "aac", "aiff"]

    /// Opens the importable files in Music without bringing it to the front.
    /// false when none of the files can be imported or Music.app is missing.
    @discardableResult
    static func add(_ files: [URL]) -> Bool {
        let importable = files.filter { importableExtensions.contains($0.pathExtension.lowercased()) }
        guard !importable.isEmpty, FileManager.default.fileExists(atPath: musicAppURL.path) else { return false }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        NSWorkspace.shared.open(importable, withApplicationAt: musicAppURL, configuration: config)
        return true
    }
}
