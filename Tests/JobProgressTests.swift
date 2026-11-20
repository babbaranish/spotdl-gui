import Foundation
import Testing

private let playlist = "https://open.spotify.com/playlist/abc"
private let track = "https://open.spotify.com/track/abc"

private func parsed(_ query: String, _ lines: [String]) -> JobProgress {
    var p = JobProgress(query: query)
    for line in lines { p.handle(line: line) }
    return p
}

private func finished(_ query: String, _ lines: [String], exitCode: Int32 = 0, cancelled: Bool = false) -> JobProgress {
    var p = parsed(query, lines)
    p.finish(exitCode: exitCode, cancelled: cancelled)
    return p
}

struct JobProgressParsingTests {
    @Test func startsWaitingWithPlaceholderTitle() {
        #expect(JobProgress(query: playlist).title == "Spotify playlist")
        #expect(JobProgress(query: playlist).state == .waiting)
        #expect(JobProgress(query: "daft punk one more time").title == "daft punk one more time")
    }

    @Test func processingQueryMeansFetching() {
        #expect(parsed(playlist, ["Processing query: \(playlist)"]).state == .fetching)
    }

    @Test func foundLineSetsTotalAndListName() {
        let p = parsed(playlist, ["Found 32 songs in Grand Theft Auto VI: The Album (Playlist)"])
        #expect(p.total == 32)
        #expect(p.title == "Grand Theft Auto VI: The Album")
        #expect(p.listName == "Grand Theft Auto VI: The Album")
    }

    @Test func completeCounterUpdatesTotal() {
        #expect(parsed(playlist, ["3/40 complete"]).total == 40)
    }

    @Test func downloadedLineMarksSongDone() {
        let p = parsed(playlist, [#"Downloaded "Artist - Song": https://music.youtube.com/watch?v=x"#])
        #expect(p.songs.map(\.name) == ["Artist - Song"])
        #expect(p.songs.first?.state == .done)
        #expect(p.state == .downloading)
    }

    @Test func statusSuffixesTrackEachSong() {
        var p = parsed(playlist, ["A - One: Downloading"])
        #expect(p.songs.first?.state == .working("Downloading"))
        #expect(p.currentSong == "A - One")

        p.handle(line: "A - One: Done")
        p.handle(line: "A - Two: Skipped")
        p.handle(line: "A - Three: Error")
        #expect(p.songs.map(\.state) == [.done, .skipped, .failed])
        #expect(p.currentSong == nil)
    }

    @Test func finishedSongIsNeverDowngraded() {
        #expect(parsed(playlist, ["A - One: Done", "A - One: Converting"]).songs.first?.state == .done)
    }

    @Test func existingFileIsSkipped() {
        let p = parsed(playlist, ["Skipping A - One (file already exists) (duplicate)"])
        #expect(p.songs.first?.name == "A - One")
        #expect(p.songs.first?.state == .skipped)
    }

    @Test func knownErrorFailsTheSongWithoutCrashing() {
        let p = parsed(playlist, ["LookupError: No results found for song: A - One"])
        #expect(p.songs.first?.name == "A - One")
        #expect(p.songs.first?.state == .failed)
        #expect(p.errors == ["No results found for song: A - One"])
        #expect(!p.crashed)
    }

    @Test func unknownErrorMeansSpotDLCrashed() {
        let p = parsed(playlist, ["SpotifyException: http status: 404"])
        #expect(p.crashed)
        #expect(p.errors == ["http status: 404"])
    }

    @Test(arguments: ["hit the rate limit", "429 Too Many Requests", "HTTP status: 429"])
    func rateLimitIsDetected(line: String) {
        #expect(parsed(playlist, ["WARNING: \(line)"]).rateLimited)
    }

    @Test func singleSongTitleBecomesTheSongName() {
        #expect(parsed(track, ["Artist - Song: Downloading"]).title == "Artist - Song")
    }

    @Test func playlistTitleIsNotReplacedBySongs() {
        #expect(parsed(playlist, ["Found 2 songs in Mix (Playlist)", "A - One: Downloading"]).title == "Mix")
    }

    @Test func blankLinesAreIgnored() {
        #expect(parsed(playlist, ["", "   "]).state == .waiting)
    }

    @Test func progressIsFinishedOverTotal() {
        let p = parsed(playlist, ["Found 4 songs in Mix (Playlist)", "A - One: Done", "A - Two: Skipped"])
        #expect(p.finishedCount == 2)
        #expect(p.progress == 0.5)
        #expect(JobProgress(query: playlist).progress == nil)
    }
}

struct JobProgressIngestTests {
    @Test func linesCanBeSplitAcrossChunks() {
        var p = JobProgress(query: playlist)
        p.ingest(Data("Found 2 songs in Mi".utf8))
        #expect(p.total == nil)
        p.ingest(Data("x (Playlist)\nA - One: Do".utf8))
        #expect(p.total == 2)
        #expect(p.title == "Mix")
        p.ingest(Data("ne\r".utf8))
        #expect(p.songs.first?.state == .done)
    }

    @Test func finishFlushesTheLastUnterminatedLine() {
        var p = JobProgress(query: playlist)
        p.ingest(Data(#"Downloaded "A - One": https://x"#.utf8))
        #expect(p.songs.isEmpty)
        p.finish(exitCode: 0, cancelled: false)
        #expect(p.songs.first?.state == .done)
        #expect(p.state == .done)
    }

    @Test func outputAfterFinishIsIgnored() {
        var p = finished(playlist, ["A - One: Done"])
        p.ingest(Data("A - Two: Done\n".utf8))
        #expect(p.songs.count == 1)
    }
}

struct JobProgressFinishTests {
    @Test func cancelledWins() {
        #expect(finished(playlist, ["A - One: Done"], cancelled: true).state == .cancelled)
    }

    @Test func rateLimitedWithNoSongs() {
        #expect(finished(playlist, ["WARNING: rate limit"]).state
            == .failed("Spotify is rate limiting spotDL right now. Try again in a few minutes."))
    }

    @Test func crashOnALinkExplainsTheLink() {
        #expect(finished(playlist, ["SpotifyException: http status: 404"], exitCode: 1).state
            == .failed("Spotify could not open this link. Check that it is a real song, album or playlist link. (http status: 404)"))
    }

    @Test func crashOnASearchShowsTheError() {
        #expect(finished("some song", ["SpotifyException: http status: 404"], exitCode: 1).state
            == .failed("http status: 404"))
    }

    @Test func lastKnownErrorIsShown() {
        #expect(finished(playlist, ["AudioProviderError: YT-DLP download error"]).state
            == .failed("YT-DLP download error"))
    }

    @Test func nonZeroExitShowsTheLastLine() {
        #expect(finished(playlist, ["Traceback (most recent call last):", "boom"], exitCode: 1).state == .failed("boom"))
    }

    @Test func nonZeroExitWithNoOutput() {
        #expect(finished(playlist, [], exitCode: 2).state == .failed("spotDL exited with code 2."))
    }

    @Test func cleanExitWithNoSongs() {
        #expect(finished(playlist, []).state == .failed("No songs found for this link or search."))
    }

    @Test func songsStillInProgressAreMarkedFailed() {
        let p = finished(playlist, ["A - One: Done", "A - Two: Downloading"])
        #expect(p.songs.map(\.state) == [.done, .failed])
        #expect(p.state == .done)
        #expect(p.currentSong == nil)
    }

    @Test func allSongsFailed() {
        #expect(finished(playlist, ["A - One: Error"]).state == .failed("The download failed."))
    }

    @Test func finishingTwiceChangesNothing() {
        var p = finished(playlist, ["A - One: Done"])
        p.finish(exitCode: 1, cancelled: true)
        #expect(p.state == .done)
    }
}

struct JobProgressDeleteTests {
    @Test func deletingLinesAreCountedAndAddNoSongs() {
        let p = parsed(playlist, ["Deleting /Music/Mix/A - Old.mp3", "Deleting /Music/Mix/B - Old.mp3"])
        #expect(p.deletedCount == 2)
        #expect(p.songs.isEmpty)
        #expect(p.state == .waiting)
    }

    @Test func syncSummaryLinesChangeNothing() {
        let p = parsed(playlist, ["Nothing to delete...", "3 old songs were deleted."])
        #expect(p.deletedCount == 0)
        #expect(p.songs.isEmpty)
        #expect(p.state == .waiting)
    }
}

struct JobProgressRestoredTests {
    @Test func restoredIsFinishedAndKeepsItsDetails() {
        var p = JobProgress.restored(
            query: playlist, title: "Mix", state: .done,
            songs: [SongRow(name: "A - One", state: .done)], listName: "Mix")
        #expect(p.kind == .playlist)
        #expect(p.title == "Mix")
        #expect(p.state == .done)
        #expect(p.finished)
        #expect(p.listName == "Mix")
        #expect(p.songs.map(\.state) == [.done])

        p.ingest(Data("A - Two: Done\n".utf8))
        #expect(p.songs.count == 1)
    }

    @Test func restoredKeepsTheDeletedCount() {
        let p = JobProgress.restored(query: playlist, title: "Mix", state: .done, songs: [], listName: "Mix",
                                     deletedCount: 3)
        #expect(p.deletedCount == 3)
        #expect(JobProgress.restored(query: playlist, title: "Mix", state: .done, songs: [], listName: nil).deletedCount == 0)
    }

    @Test func finishingARestoredJobChangesNothing() {
        var p = JobProgress.restored(query: playlist, title: "Mix", state: .failed("x"), songs: [], listName: nil)
        p.finish(exitCode: 0, cancelled: true)
        #expect(p.state == .failed("x"))
    }
}
