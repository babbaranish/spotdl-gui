import Foundation

/// Where the app keeps its own files: history, synced playlists and their save files.
enum AppPaths {
    /// ~/Library/Application Support/spotdl-gui, created on access.
    static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        let dir = base.appendingPathComponent("spotdl-gui", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Moves a file the app could not read to <name>.bak (replacing an older one), so the next save
    /// does not overwrite it. Does nothing when the file is missing.
    static func moveAside(_ url: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }
        let backup = url.appendingPathExtension("bak")
        try? fm.removeItem(at: backup)
        try? fm.moveItem(at: url, to: backup)
    }
}
