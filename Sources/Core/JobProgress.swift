import Foundation

/// Everything the app knows about one spotDL run, built from its output.
/// A plain value so the parsing rules can be tested without launching spotDL.
struct JobProgress: Equatable {
    let query: String
    let kind: JobKind

    var title: String
    var state: JobState = .waiting
    var total: Int?
    var songs: [SongRow] = []
    var errors: [String] = []
    var currentSong: String?
    var rateLimited = false
    var crashed = false
    var listName: String?
    private(set) var finished = false

    private var buffer = Data()
    private var lastLines: [String] = []

    init(query: String) {
        self.query = query
        self.kind = JobKind(query: query)
        self.title = kind == .search ? query : kind.placeholderTitle
    }

    var doneCount: Int { songs.filter { $0.state == .done }.count }
    var skippedCount: Int { songs.filter { $0.state == .skipped }.count }
    var failedCount: Int { songs.filter { $0.state == .failed }.count }
    var finishedCount: Int { doneCount + skippedCount + failedCount }

    var progress: Double? {
        guard let total, total > 0 else { return nil }
        return min(1, Double(finishedCount) / Double(total))
    }

    // MARK: Output parsing

    /// Per-song errors spotDL reports normally; anything else means spotDL itself crashed.
    private static let downloadErrors: Set<String> = [
        "LookupError", "AudioProviderError", "DownloaderError", "FFmpegError", "MetadataError",
    ]

    private static let songStatuses = [
        "Searching for song", "Getting audio meta", "Downloading", "Converting",
        "Embedding metadata", "Done", "Skipped", "Error",
    ]

    /// Feeds raw process output; complete lines (ending in \n or \r) are handled right away.
    mutating func ingest(_ data: Data) {
        guard !finished else { return }
        buffer.append(data)
        while let idx = buffer.firstIndex(where: { $0 == 10 || $0 == 13 }) {
            let lineData = buffer[buffer.startIndex..<idx]
            buffer.removeSubrange(buffer.startIndex...idx)
            handle(line: String(decoding: lineData, as: UTF8.self))
        }
    }

    mutating func handle(line raw: String) {
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return }
        lastLines.append(line)
        if lastLines.count > 30 { lastLines.removeFirst() }

        let lower = line.lowercased()
        if lower.contains("rate limit") || lower.contains("too many requests") || lower.contains("status: 429") {
            rateLimited = true
        }

        if line.hasPrefix("Processing query:") {
            if state == .waiting { state = .fetching }
            return
        }

        // "Found 32 songs in Grand Theft Auto VI: The Album (Playlist)"
        if line.hasPrefix("Found "), let m = line.firstMatch(of: /^Found (\d+) songs in (.+) \((\w+)\)$/) {
            total = Int(m.1)
            let name = String(m.2)
            listName = name
            title = name
            return
        }

        // "3/32 complete"
        if let m = line.firstMatch(of: /^(\d+)\/(\d+) complete$/) {
            total = Int(m.2)
            return
        }

        // 'Downloaded "Artist - Song": https://...'
        if let m = line.firstMatch(of: #/^Downloaded "(.+)": /#) {
            setSong(String(m.1), .done)
            return
        }

        // "LookupError: No results found for song: Artist - Song"
        if let m = line.firstMatch(of: /^([A-Za-z]+(?:Error|Exception)): (.+)$/) {
            let message = String(m.2)
            if !Self.downloadErrors.contains(String(m.1)) { crashed = true }
            errors.append(message)
            if let s = message.firstMatch(of: /No results found for song: (.+)$/) {
                setSong(String(s.1), .failed)
            }
            return
        }

        // "Artist - Song: Downloading"
        for status in Self.songStatuses where line.hasSuffix(": " + status) {
            let name = String(line.dropLast(status.count + 2))
            switch status {
            case "Done": setSong(name, .done)
            case "Skipped": setSong(name, .skipped)
            case "Error": setSong(name, .failed)
            default:
                setSong(name, .working(status))
                currentSong = name
            }
            return
        }

        if line.hasPrefix("Skipping ") && line.contains("(file already exists)") {
            if let m = line.firstMatch(of: /^Skipping (.+) \(file already exists\)/) {
                setSong(String(m.1), .skipped)
            }
        }
    }

    /// Settles the final state once spotDL has exited and its output is closed.
    mutating func finish(exitCode: Int32, cancelled: Bool) {
        guard !finished else { return }
        flush()
        finished = true
        currentSong = nil
        // spotDL does not print a per-song line for most errors, so anything still in progress failed.
        for i in songs.indices where !songs[i].isFinished { songs[i].state = .failed }
        if cancelled {
            state = .cancelled
        } else if songs.isEmpty {
            if rateLimited {
                state = .failed("Spotify is rate limiting spotDL right now. Try again in a few minutes.")
            } else if crashed && kind != .search {
                state = .failed("Spotify could not open this link. Check that it is a real song, album or playlist link. (\(errors.last ?? ""))")
            } else if let e = errors.last {
                state = .failed(e)
            } else if exitCode != 0 {
                state = .failed(lastLines.last ?? "spotDL exited with code \(exitCode).")
            } else {
                state = .failed("No songs found for this link or search.")
            }
        } else if doneCount + skippedCount == 0 {
            state = .failed(errors.last ?? "The download failed.")
        } else {
            state = .done
        }
    }

    private mutating func flush() {
        if !buffer.isEmpty {
            handle(line: String(decoding: buffer, as: UTF8.self))
            buffer.removeAll()
        }
    }

    private mutating func setSong(_ name: String, _ newState: SongState) {
        state = .downloading
        if kind == .track || kind == .search, total == nil || total == 1 { title = name }
        if let i = songs.firstIndex(where: { $0.name == name }) {
            // Never downgrade a finished song back to "working".
            if case .working = newState, songs[i].isFinished { return }
            songs[i].state = newState
        } else {
            songs.append(SongRow(name: name, state: newState))
        }
        if newState == .done || newState == .skipped || newState == .failed, currentSong == name {
            currentSong = nil
        }
    }
}
