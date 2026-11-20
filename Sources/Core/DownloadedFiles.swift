import Foundation

/// Finds the files a finished job wrote, so the app can reveal them or add them to Music.
enum DownloadedFiles {
    static let audioExtensions: Set<String> = ["mp3", "m4a", "flac", "opus", "ogg", "wav"]

    /// The folder for list jobs (outputDir/sanitize(listName)) if it exists, else outputDir.
    static func folder(outputDir: URL, kind: JobKind, listName: String?, fileManager: FileManager = .default) -> URL {
        guard kind.usesFolder, let listName else { return outputDir }
        let name = SpotDLCommand.sanitize(listName)
        guard !name.isEmpty else { return outputDir }
        let candidate = outputDir.appendingPathComponent(name, isDirectory: true)
        return fileManager.fileExists(atPath: candidate.path) ? candidate : outputDir
    }

    /// Audio files directly inside `folder(...)` modified at or after startedAt - 2s, newest first.
    /// With `before`, also modified at or before before + 2s.
    static func find(outputDir: URL, kind: JobKind, listName: String?, startedAt: Date, before: Date? = nil,
                     fileManager: FileManager = .default) -> [URL] {
        let dir = folder(outputDir: outputDir, kind: kind, listName: listName, fileManager: fileManager)
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        guard let items = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: keys,
                                                               options: [.skipsHiddenFiles]) else { return [] }
        let cutoff = startedAt.addingTimeInterval(-2)
        let ceiling = before?.addingTimeInterval(2)
        var found: [(url: URL, date: Date)] = []
        for url in items where audioExtensions.contains(url.pathExtension.lowercased()) {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate, modified >= cutoff,
                  ceiling.map({ modified <= $0 }) ?? true
            else { continue }
            found.append((url, modified))
        }
        return found.sorted { $0.date > $1.date }.map(\.url)
    }
}
