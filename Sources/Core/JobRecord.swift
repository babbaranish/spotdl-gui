import Foundation

/// One song in a saved job. `status` is "done", "skipped" or "failed".
struct SongRecord: Codable, Equatable {
    var name: String
    var status: String
}

/// A finished (or interrupted) download, saved to history so it can be shown and retried.
struct JobRecord: Codable, Equatable {
    enum Outcome: String, Codable { case done, failed, cancelled, interrupted }

    var query: String
    var title: String
    var options: DownloadOptions
    var outputDir: String
    var outcome: Outcome
    var message: String?          // failure message for .failed
    var songs: [SongRecord]
    var listName: String?
    var artworkURL: String?
    var syncedPlaylistID: UUID?
    var finishedAt: Date?
    var deletedCount: Int         // songs a sync removed from the folder; 0 for other jobs

    private enum CodingKeys: String, CodingKey {
        case query, title, options, outputDir, outcome, message, songs, listName, artworkURL
        case syncedPlaylistID, finishedAt, deletedCount
    }

    /// Only query, title, outputDir and outcome are required; records saved by older versions
    /// may lack the rest, so they take the defaults shown here.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        query = try c.decode(String.self, forKey: .query)
        title = try c.decode(String.self, forKey: .title)
        options = try c.decodeIfPresent(DownloadOptions.self, forKey: .options) ?? DownloadOptions()
        outputDir = try c.decode(String.self, forKey: .outputDir)
        outcome = try c.decode(Outcome.self, forKey: .outcome)
        message = try c.decodeIfPresent(String.self, forKey: .message)
        songs = try c.decodeIfPresent([SongRecord].self, forKey: .songs) ?? []
        listName = try c.decodeIfPresent(String.self, forKey: .listName)
        artworkURL = try c.decodeIfPresent(String.self, forKey: .artworkURL)
        syncedPlaylistID = try c.decodeIfPresent(UUID.self, forKey: .syncedPlaylistID)
        finishedAt = try c.decodeIfPresent(Date.self, forKey: .finishedAt)
        deletedCount = try c.decodeIfPresent(Int.self, forKey: .deletedCount) ?? 0
    }

    /// Active states (waiting/fetching/downloading) become .interrupted; working songs become "failed".
    init(progress: JobProgress, options: DownloadOptions, outputDir: String,
         artworkURL: String?, syncedPlaylistID: UUID?, finishedAt: Date?) {
        self.query = progress.query
        self.title = progress.title
        self.options = options
        self.outputDir = outputDir
        switch progress.state {
        case .done:
            outcome = .done
            message = nil
        case .failed(let text):
            outcome = .failed
            message = text
        case .cancelled:
            outcome = .cancelled
            message = nil
        case .waiting, .fetching, .downloading:
            outcome = .interrupted
            message = nil
        }
        self.songs = progress.songs.map { song in
            switch song.state {
            case .done: return SongRecord(name: song.name, status: "done")
            case .skipped: return SongRecord(name: song.name, status: "skipped")
            case .failed, .working: return SongRecord(name: song.name, status: "failed")
            }
        }
        self.listName = progress.listName
        self.artworkURL = artworkURL
        self.syncedPlaylistID = syncedPlaylistID
        self.finishedAt = finishedAt
        self.deletedCount = progress.deletedCount
    }

    /// done -> .done, failed -> .failed(message ?? "The download failed."), cancelled -> .cancelled,
    /// interrupted -> .failed("Stopped when the app quit. Press Retry.")
    func restoredProgress() -> JobProgress {
        let state: JobState
        switch outcome {
        case .done: state = .done
        case .failed: state = .failed(message ?? "The download failed.")
        case .cancelled: state = .cancelled
        case .interrupted: state = .failed("Stopped when the app quit. Press Retry.")
        }
        let rows = songs.map { record -> SongRow in
            switch record.status {
            case "done": return SongRow(name: record.name, state: .done)
            case "skipped": return SongRow(name: record.name, state: .skipped)
            default: return SongRow(name: record.name, state: .failed)
            }
        }
        return JobProgress.restored(query: query, title: title, state: state, songs: rows, listName: listName,
                                    deletedCount: deletedCount)
    }

    static let historyLimit = 200
}
