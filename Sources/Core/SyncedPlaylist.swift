import Foundation

/// A Spotify playlist, album or artist that is kept in sync with an output folder.
struct SyncedPlaylist: Codable, Identifiable, Equatable {
    var id: UUID
    var url: String
    var title: String
    var outputDir: String
    var saveFilePath: String      // <saveFileDirectory>/<id>.spotdl
    var format: AudioFormat       // captured when added, so later global changes don't re-encode the folder
    var fileNameTemplate: String  // captured when added; validated again when syncing
    var deleteRemoved: Bool       // false = pass --sync-without-deleting
    var lastSynced: Date?

    private enum CodingKeys: String, CodingKey {
        case id, url, title, outputDir, saveFilePath, format, fileNameTemplate, deleteRemoved, lastSynced
    }

    init(url: String, title: String, outputDir: String, saveFileDirectory: URL,
         format: AudioFormat, fileNameTemplate: String, deleteRemoved: Bool = false) {
        self.id = UUID()
        self.url = url
        self.title = title
        self.outputDir = outputDir
        self.saveFilePath = saveFileDirectory.appendingPathComponent("\(id.uuidString).spotdl").path
        self.format = format
        self.fileNameTemplate = fileNameTemplate
        self.deleteRemoved = deleteRemoved
        self.lastSynced = nil
    }

    /// Playlists saved before format and fileNameTemplate existed get the defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        url = try c.decode(String.self, forKey: .url)
        title = try c.decode(String.self, forKey: .title)
        outputDir = try c.decode(String.self, forKey: .outputDir)
        saveFilePath = try c.decode(String.self, forKey: .saveFilePath)
        format = try c.decodeIfPresent(AudioFormat.self, forKey: .format) ?? .mp3
        fileNameTemplate = try c.decodeIfPresent(String.self, forKey: .fileNameTemplate)
            ?? DownloadOptions.defaultFileNameTemplate
        deleteRemoved = try c.decodeIfPresent(Bool.self, forKey: .deleteRemoved) ?? false
        lastSynced = try c.decodeIfPresent(Date.self, forKey: .lastSynced)
    }

    /// Spotify link whose JobKind is playlist, album or artist.
    static func canSync(_ url: String) -> Bool {
        guard QueryInput.isSpotifyLink(url) else { return false }
        let kind = JobKind(query: url)
        return kind == .playlist || kind == .album || kind == .artist
    }
}
