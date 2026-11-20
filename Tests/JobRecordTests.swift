import Foundation
import Testing

private let listQuery = "https://open.spotify.com/playlist/abc"
private let when = Date(timeIntervalSince1970: 1_700_000_000)

private func progress(_ lines: [String], finish: Bool = true, exitCode: Int32 = 0, cancelled: Bool = false) -> JobProgress {
    var p = JobProgress(query: listQuery)
    for line in lines { p.handle(line: line) }
    if finish { p.finish(exitCode: exitCode, cancelled: cancelled) }
    return p
}

private func record(_ p: JobProgress) -> JobRecord {
    JobRecord(progress: p, options: DownloadOptions(format: .flac), outputDir: "/Music",
              artworkURL: "https://i.scdn.co/image/a.jpg", syncedPlaylistID: nil, finishedAt: when)
}

struct JobRecordTests {
    @Test func finishedDownloadKeepsSongsAndDetails() {
        let r = record(progress(["Found 2 songs in Mix (Playlist)", "A - One: Done", "A - Two: Skipped"]))
        #expect(r.query == listQuery)
        #expect(r.title == "Mix")
        #expect(r.outcome == .done)
        #expect(r.message == nil)
        #expect(r.songs == [SongRecord(name: "A - One", status: "done"), SongRecord(name: "A - Two", status: "skipped")])
        #expect(r.listName == "Mix")
        #expect(r.options == DownloadOptions(format: .flac))
        #expect(r.outputDir == "/Music")
        #expect(r.artworkURL == "https://i.scdn.co/image/a.jpg")
        #expect(r.syncedPlaylistID == nil)
        #expect(r.finishedAt == when)
    }

    @Test func failedSongsAreRecordedAsFailed() {
        let r = record(progress(["A - One: Done", "A - Two: Error"]))
        #expect(r.songs.map(\.status) == ["done", "failed"])
    }

    @Test func failureKeepsItsMessage() {
        let r = record(progress(["AudioProviderError: YT-DLP download error"]))
        #expect(r.outcome == .failed)
        #expect(r.message == "YT-DLP download error")
    }

    @Test func cancelledDownload() {
        let r = record(progress(["A - One: Done", "A - Two: Downloading"], cancelled: true))
        #expect(r.outcome == .cancelled)
        #expect(r.message == nil)
        #expect(r.songs.map(\.status) == ["done", "failed"])
    }

    @Test func unfinishedDownloadIsInterrupted() {
        let r = record(progress(["Found 3 songs in Mix (Playlist)", "A - One: Done", "A - Two: Downloading"], finish: false))
        #expect(r.outcome == .interrupted)
        #expect(r.songs.map(\.status) == ["done", "failed"])
        #expect(r.message == nil)
    }

    @Test func waitingDownloadIsInterrupted() {
        #expect(record(progress([], finish: false)).outcome == .interrupted)
    }

    @Test func restoredDoneKeepsSongStates() {
        let p = record(progress(["A - One: Done", "A - Two: Skipped"])).restoredProgress()
        #expect(p.state == .done)
        #expect(p.finished)
        #expect(p.songs.map(\.state) == [.done, .skipped])
    }

    @Test func restoredFailureUsesTheStoredMessage() {
        #expect(record(progress(["AudioProviderError: boom"])).restoredProgress().state == .failed("boom"))
    }

    @Test func restoredFailureWithoutMessageFallsBack() {
        var r = record(progress(["A - One: Done"]))
        r.outcome = .failed
        r.message = nil
        #expect(r.restoredProgress().state == .failed("The download failed."))
    }

    @Test func restoredCancelled() {
        #expect(record(progress(["A - One: Done"], cancelled: true)).restoredProgress().state == .cancelled)
    }

    @Test func restoredInterruptedSaysItStopped() {
        #expect(record(progress([], finish: false)).restoredProgress().state
            == .failed("Stopped when the app quit. Press Retry."))
    }

    @Test func restoredSongsStayFailedWhenInterrupted() {
        let p = record(progress(["A - One: Done", "A - Two: Downloading"], finish: false)).restoredProgress()
        #expect(p.songs.map(\.state) == [.done, .failed])
    }

    @Test func restoredProgressKeepsTitleAndListName() {
        let p = record(progress(["Found 1 songs in Mix (Playlist)", "A - One: Done"])).restoredProgress()
        #expect(p.title == "Mix")
        #expect(p.listName == "Mix")
        #expect(p.kind == .playlist)
    }

    @Test func restoredProgressIgnoresOutput() {
        var p = record(progress(["A - One: Done"])).restoredProgress()
        p.ingest(Data("A - Two: Done\n".utf8))
        #expect(p.songs.count == 1)
    }

    @Test func historyIsCappedAt200() {
        #expect(JobRecord.historyLimit == 200)
    }

    @Test func keepsTheDeletedCountAcrossRestore() {
        let r = record(progress(["Found 2 songs in Mix (Playlist)", "A - One: Done", "Deleting /Music/Mix/old.mp3",
                                 "Deleting /Music/Mix/older.mp3"]))
        #expect(r.deletedCount == 2)
        #expect(r.restoredProgress().deletedCount == 2)
    }

    @Test func deletedCountSurvivesJSON() throws {
        var r = record(progress(["A - One: Done"]))
        r.deletedCount = 4
        let decoded = try JSONDecoder().decode(JobRecord.self, from: JSONEncoder().encode(r))
        #expect(decoded.deletedCount == 4)
    }

    @Test func iso8601RoundTrip() throws {
        var r = record(progress(["Found 1 songs in Mix (Playlist)", "A - One: Done", "Deleting /x.mp3"]))
        r.syncedPlaylistID = UUID()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(JobRecord.self, from: encoder.encode(r))
        #expect(decoded == r)
    }

    /// Only the required keys: everything else takes its default.
    @Test func missingOptionalKeysUseDefaults() throws {
        let json = #"{"query":"https://open.spotify.com/playlist/abc","title":"Mix","outputDir":"/Music","outcome":"done"}"#
        let r = try JSONDecoder().decode(JobRecord.self, from: Data(json.utf8))
        #expect(r.outcome == .done)
        #expect(r.options == DownloadOptions())
        #expect(r.songs.isEmpty)
        #expect(r.deletedCount == 0)
        #expect(r.message == nil)
        #expect(r.listName == nil)
        #expect(r.artworkURL == nil)
        #expect(r.syncedPlaylistID == nil)
        #expect(r.finishedAt == nil)
    }

    @Test func roundTripsThroughJSON() throws {
        var r = record(progress(["Found 1 songs in Mix (Playlist)", "A - One: Done"]))
        r.syncedPlaylistID = UUID()
        let decoded = try JSONDecoder().decode(JobRecord.self, from: JSONEncoder().encode(r))
        #expect(decoded == r)
    }
}
