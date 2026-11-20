import AppKit
import Combine

/// One queued download: the parsed spotDL state plus the process running it.
@MainActor
final class Job: ObservableObject, Identifiable {
    let id = UUID()
    let format: AudioFormat
    let outputDir: URL

    @Published private(set) var run: JobProgress
    @Published var showSongs = false

    var startedAt = Date()
    var process: Process?
    var cancelRequested = false
    var outputClosed = false
    var exitCode: Int32?

    init(query: String, format: AudioFormat, outputDir: URL) {
        self.run = JobProgress(query: query)
        self.format = format
        self.outputDir = outputDir
    }

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
    var progress: Double? { run.progress }

    func ingest(_ data: Data) { run.ingest(data) }

    func finish(exitCode: Int32) {
        guard !run.finished else { return }
        run.finish(exitCode: exitCode, cancelled: cancelRequested)
        process = nil
    }

    // MARK: Finder

    func reveal() {
        let fm = FileManager.default
        if kind.usesFolder, let listName = run.listName {
            let folder = outputDir.appendingPathComponent(SpotDLCommand.sanitize(listName), isDirectory: true)
            if fm.fileExists(atPath: folder.path) {
                NSWorkspace.shared.open(folder)
                return
            }
        }
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let items = (try? fm.contentsOfDirectory(at: outputDir, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        let recent = items
            .compactMap { url -> (URL, Date)? in
                guard let d = try? url.resourceValues(forKeys: Set(keys)).contentModificationDate,
                      d >= startedAt.addingTimeInterval(-2) else { return nil }
                return (url, d)
            }
            .sorted { $0.1 > $1.1 }
        if let newest = recent.first?.0 {
            NSWorkspace.shared.activateFileViewerSelecting([newest])
        } else {
            NSWorkspace.shared.open(outputDir)
        }
    }
}
