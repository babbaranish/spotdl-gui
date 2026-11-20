import Foundation
import Testing

struct DownloadedFilesTests {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DownloadedFilesTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func touch(_ url: URL, at date: Date) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: url)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }

    @Test func audioExtensions() {
        #expect(DownloadedFiles.audioExtensions == ["mp3", "m4a", "flac", "opus", "ogg", "wav"])
    }

    @Test func listJobsUseTheSanitizedListFolderWhenItExists() throws {
        let out = try makeDir()
        defer { try? FileManager.default.removeItem(at: out) }
        try FileManager.default.createDirectory(at: out.appendingPathComponent("ACDC Live"), withIntermediateDirectories: true)
        let folder = DownloadedFiles.folder(outputDir: out, kind: .album, listName: "AC/DC Live")
        #expect(folder.path == out.appendingPathComponent("ACDC Live", isDirectory: true).path)
    }

    @Test func listJobsFallBackToTheOutputFolder() throws {
        let out = try makeDir()
        defer { try? FileManager.default.removeItem(at: out) }
        #expect(DownloadedFiles.folder(outputDir: out, kind: .playlist, listName: "Missing").path == out.path)
        #expect(DownloadedFiles.folder(outputDir: out, kind: .playlist, listName: nil).path == out.path)
    }

    @Test func singleSongsAlwaysUseTheOutputFolder() throws {
        let out = try makeDir()
        defer { try? FileManager.default.removeItem(at: out) }
        try FileManager.default.createDirectory(at: out.appendingPathComponent("Mix"), withIntermediateDirectories: true)
        #expect(DownloadedFiles.folder(outputDir: out, kind: .track, listName: "Mix").path == out.path)
        #expect(DownloadedFiles.folder(outputDir: out, kind: .search, listName: nil).path == out.path)
    }

    @Test func findsNewAudioFilesNewestFirst() throws {
        let out = try makeDir()
        defer { try? FileManager.default.removeItem(at: out) }
        try touch(out.appendingPathComponent("older.flac"), at: base.addingTimeInterval(5))
        try touch(out.appendingPathComponent("newer.mp3"), at: base.addingTimeInterval(10))
        try touch(out.appendingPathComponent("UPPER.M4A"), at: base.addingTimeInterval(7))
        let found = DownloadedFiles.find(outputDir: out, kind: .track, listName: nil, startedAt: base)
        #expect(found.map(\.lastPathComponent) == ["newer.mp3", "UPPER.M4A", "older.flac"])
    }

    @Test func ignoresOlderFilesNonAudioAndSubfolders() throws {
        let out = try makeDir()
        defer { try? FileManager.default.removeItem(at: out) }
        try touch(out.appendingPathComponent("stale.mp3"), at: base.addingTimeInterval(-3))
        try touch(out.appendingPathComponent("edge.mp3"), at: base.addingTimeInterval(-2))
        try touch(out.appendingPathComponent("cover.jpg"), at: base.addingTimeInterval(1))
        try touch(out.appendingPathComponent("song.lrc"), at: base.addingTimeInterval(1))
        try touch(out.appendingPathComponent("sub/deep.mp3"), at: base.addingTimeInterval(1))
        try touch(out.appendingPathComponent("new.mp3"), at: base.addingTimeInterval(1))
        let found = DownloadedFiles.find(outputDir: out, kind: .track, listName: nil, startedAt: base)
        #expect(found.map(\.lastPathComponent) == ["new.mp3", "edge.mp3"])
    }

    @Test func beforeCapsTheNewestModificationTime() throws {
        let out = try makeDir()
        defer { try? FileManager.default.removeItem(at: out) }
        try touch(out.appendingPathComponent("early.mp3"), at: base.addingTimeInterval(-3))
        try touch(out.appendingPathComponent("in.mp3"), at: base.addingTimeInterval(1))
        try touch(out.appendingPathComponent("edge.mp3"), at: base.addingTimeInterval(12))
        try touch(out.appendingPathComponent("late.mp3"), at: base.addingTimeInterval(13))
        let found = DownloadedFiles.find(outputDir: out, kind: .track, listName: nil, startedAt: base,
                                         before: base.addingTimeInterval(10))
        #expect(found.map(\.lastPathComponent) == ["edge.mp3", "in.mp3"])
    }

    @Test func noBeforeKeepsEverythingNewerThanStart() throws {
        let out = try makeDir()
        defer { try? FileManager.default.removeItem(at: out) }
        try touch(out.appendingPathComponent("late.mp3"), at: base.addingTimeInterval(1000))
        let found = DownloadedFiles.find(outputDir: out, kind: .track, listName: nil, startedAt: base)
        #expect(found.map(\.lastPathComponent) == ["late.mp3"])
    }

    @Test func listJobsOnlySearchTheirFolder() throws {
        let out = try makeDir()
        defer { try? FileManager.default.removeItem(at: out) }
        try touch(out.appendingPathComponent("Mix/one.mp3"), at: base.addingTimeInterval(1))
        try touch(out.appendingPathComponent("loose.mp3"), at: base.addingTimeInterval(2))
        let inList = DownloadedFiles.find(outputDir: out, kind: .playlist, listName: "Mix", startedAt: base)
        #expect(inList.map(\.lastPathComponent) == ["one.mp3"])
        let fallback = DownloadedFiles.find(outputDir: out, kind: .playlist, listName: "Nope", startedAt: base)
        #expect(fallback.map(\.lastPathComponent) == ["loose.mp3"])
    }

    @Test func missingFolderGivesNothing() throws {
        let out = try makeDir()
        defer { try? FileManager.default.removeItem(at: out) }
        let missing = out.appendingPathComponent("missing", isDirectory: true)
        #expect(DownloadedFiles.find(outputDir: missing, kind: .track, listName: nil, startedAt: base).isEmpty)
    }
}
