import AppKit
import Combine

/// A plain download, or a sync of a saved playlist (spotdl sync).
enum JobMode: Equatable {
    case download, sync(SyncedPlaylist)
}

/// One queued download: the parsed spotDL state plus the process running it.
@MainActor
final class Job: ObservableObject, Identifiable {
    let id = UUID()
    let options: DownloadOptions
    let outputDir: URL
    let mode: JobMode

    @Published private(set) var run: JobProgress
    @Published var showSongs = false
    @Published var artworkURL: URL?
    /// The failed song whose Fix sheet is open.
    @Published var fixingSong: String?

    /// Set when spotDL starts. nil for jobs restored from history, which have no real start time.
    var startedAt: Date?
    var finishedAt: Date?
    var process: Process?
    var cancelRequested = false
    var outputClosed = false
    var exitCode: Int32?

    /// Sync jobs use the playlist link as the query and its saved title until spotDL reports the real name.
    init(query: String, options: DownloadOptions, outputDir: URL, mode: JobMode = .download) {
        var run: JobProgress
        if case .sync(let playlist) = mode {
            run = JobProgress(query: playlist.url)
            run.title = playlist.title
        } else {
            run = JobProgress(query: query)
        }
        self.run = run
        self.options = options
        self.outputDir = outputDir
        self.mode = mode
    }

    /// A finished job from history. It is linked to its synced playlist only while that playlist is still saved.
    init(record: JobRecord) {
        run = record.restoredProgress()
        options = record.options
        outputDir = URL(fileURLWithPath: record.outputDir, isDirectory: true)
        if let id = record.syncedPlaylistID, let playlist = SyncStore.shared.playlists.first(where: { $0.id == id }) {
            mode = .sync(playlist)
        } else {
            mode = .download
        }
        artworkURL = record.artworkURL.flatMap { URL(string: $0) }
        finishedAt = record.finishedAt
    }

    var record: JobRecord {
        JobRecord(progress: run, options: options, outputDir: outputDir.path,
                  artworkURL: artworkURL?.absoluteString, syncedPlaylistID: syncedPlaylist?.id,
                  finishedAt: finishedAt)
    }

    var syncedPlaylist: SyncedPlaylist? {
        if case .sync(let playlist) = mode { return playlist }
        return nil
    }

    /// A sync downloads in its playlist's saved format, not the job's options.
    var format: AudioFormat { syncedPlaylist?.format ?? options.format }
    var query: String { run.query }
    var kind: JobKind { run.kind }
    var title: String { run.title }
    var state: JobState {
        get { run.state }
        set { run.state = newValue }
    }
    var total: Int? { run.total }
    var songs: [SongRow] { run.songs }
    var currentSong: String? { run.currentSong }
    var rateLimited: Bool { run.rateLimited }
    var isFinished: Bool { run.finished }
    var doneCount: Int { run.doneCount }
    var skippedCount: Int { run.skippedCount }
    var failedCount: Int { run.failedCount }
    var finishedCount: Int { run.finishedCount }
    var deletedCount: Int { run.deletedCount }
    var progress: Double? { run.progress }

    /// Result of a finished download: "Downloaded", "Already downloaded", "12 saved, 1 failed", or "" when nothing happened.
    var doneSummary: String {
        if deletedCount == 0 {
            if songs.count == 1 && doneCount == 1 { return "Downloaded" }
            if songs.count == 1 && skippedCount == 1 { return "Already downloaded" }
        }
        var parts: [String] = []
        if doneCount > 0 { parts.append("\(doneCount) saved") }
        if skippedCount > 0 { parts.append("\(skippedCount) already downloaded") }
        if failedCount > 0 { parts.append("\(failedCount) failed") }
        if deletedCount > 0 { parts.append("\(deletedCount) removed") }
        return parts.joined(separator: ", ")
    }

    func ingest(_ data: Data) { run.ingest(data) }

    func finish(exitCode: Int32) {
        guard !run.finished else { return }
        run.finish(exitCode: exitCode, cancelled: cancelRequested)
        finishedAt = Date()
        process = nil
    }

    // MARK: Files

    /// spotDL's list name, or the synced playlist's saved title when a sync did not print one.
    private var listName: String? { run.listName ?? syncedPlaylist?.title }

    /// The list's own folder if it exists, else the output folder.
    var folder: URL {
        DownloadedFiles.folder(outputDir: outputDir, kind: kind, listName: listName)
    }

    /// Audio files written by this run (not ones skipped as already downloaded), between its start and finish.
    /// Empty for jobs restored from history, since they have no start time.
    var newFiles: [URL] {
        guard let startedAt else { return [] }
        return DownloadedFiles.find(outputDir: outputDir, kind: kind, listName: listName,
                                    startedAt: startedAt, before: finishedAt)
    }

    /// Files for "Add to Music": the whole list folder, else this run's new files, else files named after its songs.
    /// The last case covers jobs restored from history and songs that were already downloaded.
    var savedFiles: [URL] {
        if folder != outputDir {
            return DownloadedFiles.find(outputDir: outputDir, kind: kind, listName: listName, startedAt: .distantPast)
        }
        let recent = newFiles
        return recent.isEmpty ? filesNamedAfterSongs : recent
    }

    /// Audio files in the output folder named after this job's saved or skipped songs.
    private var filesNamedAfterSongs: [URL] {
        let all = DownloadedFiles.find(outputDir: outputDir, kind: kind, listName: listName, startedAt: .distantPast)
        let names = Set(songs.filter { $0.state != .failed }.map { SpotDLCommand.sanitize($0.name) })
        return all.filter { names.contains($0.deletingPathExtension().lastPathComponent) }
    }

    // MARK: Finder

    func reveal() {
        let dir = folder
        if dir != outputDir {
            NSWorkspace.shared.open(dir)
        } else if let file = newFiles.first ?? filesNamedAfterSongs.first {
            NSWorkspace.shared.activateFileViewerSelecting([file])
        } else {
            NSWorkspace.shared.open(outputDir)
        }
    }
}
