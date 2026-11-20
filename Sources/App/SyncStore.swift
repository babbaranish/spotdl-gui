import Foundation

/// The playlists, albums and artists kept in sync. The list is JSON in the support folder;
/// each one has a .spotdl save file in the sync folder.
@MainActor
final class SyncStore: ObservableObject {
    static let shared = SyncStore()

    @Published private(set) var playlists: [SyncedPlaylist]

    private static var fileURL: URL {
        AppPaths.supportDirectory.appendingPathComponent("synced-playlists.json")
    }

    private static var saveFileDirectory: URL {
        let dir = AppPaths.supportDirectory.appendingPathComponent("sync", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private init() {
        playlists = Self.load()
    }

    /// nil if the link cannot be synced or is already in the list. The playlist keeps the format and
    /// file name it was added with, so later changes in Settings do not re-encode or rename its folder.
    func add(url: String, title: String, outputDir: URL, options: DownloadOptions) -> SyncedPlaylist? {
        let link = Self.normalizedLink(url)
        guard SyncedPlaylist.canSync(link), !contains(url: link) else { return nil }
        let playlist = SyncedPlaylist(url: link, title: title, outputDir: outputDir.path,
                                      saveFileDirectory: Self.saveFileDirectory,
                                      format: options.format, fileNameTemplate: options.effectiveTemplate)
        playlists.append(playlist)
        save()
        return playlist
    }

    /// Removes the playlist and its .spotdl save file.
    func remove(_ id: UUID) {
        guard let playlist = playlists.first(where: { $0.id == id }) else { return }
        try? FileManager.default.removeItem(atPath: playlist.saveFilePath)
        playlists.removeAll { $0.id == id }
        save()
    }

    func update(_ playlist: SyncedPlaylist) {
        guard let i = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[i] = playlist
        save()
    }

    /// Stamps lastSynced now. A non-empty title (the list name from spotDL) replaces the old one.
    func markSynced(_ id: UUID, title: String?) {
        guard var playlist = playlists.first(where: { $0.id == id }) else { return }
        playlist.lastSynced = Date()
        if let title, !title.isEmpty { playlist.title = title }
        update(playlist)
    }

    /// Compares links without their query string or trailing slash, so ".../playlist/ID?si=abc" matches ".../playlist/ID".
    func contains(url: String) -> Bool {
        let link = Self.normalizedLink(url)
        return playlists.contains { Self.normalizedLink($0.url) == link }
    }

    /// The link trimmed, without its query string or trailing slash.
    private static func normalizedLink(_ url: String) -> String {
        var link = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if let q = link.firstIndex(of: "?") { link = String(link[..<q]) }
        while link.hasSuffix("/") { link.removeLast() }
        return link
    }

    /// Empty when there is no file. A file that cannot be read is moved to synced-playlists.json.bak
    /// so the next save does not overwrite it.
    private static func load() -> [SyncedPlaylist] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        if let data = try? Data(contentsOf: fileURL),
           let playlists = try? decoder.decode([SyncedPlaylist].self, from: data) {
            return playlists
        }
        AppPaths.moveAside(fileURL)
        return []
    }

    private func save() {
        guard let data = try? Self.encoder.encode(playlists) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
