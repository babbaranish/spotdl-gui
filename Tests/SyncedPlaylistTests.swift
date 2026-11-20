import Foundation
import Testing

struct SyncedPlaylistTests {
    private let saveDir = URL(fileURLWithPath: "/sync-test")
    private let link = "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M"

    @Test func newPlaylistGetsItsOwnSaveFile() {
        let p = SyncedPlaylist(url: link, title: "Mix", outputDir: "/Music", saveFileDirectory: saveDir,
                               format: .mp3, fileNameTemplate: "{title}.{output-ext}")
        #expect(p.url == link)
        #expect(p.title == "Mix")
        #expect(p.outputDir == "/Music")
        #expect(p.saveFilePath == saveDir.appendingPathComponent("\(p.id.uuidString).spotdl").path)
        #expect(p.deleteRemoved == false)
        #expect(p.lastSynced == nil)
    }

    @Test func playlistKeepsTheFormatAndTemplateItWasAddedWith() {
        let p = SyncedPlaylist(url: link, title: "Mix", outputDir: "/M", saveFileDirectory: saveDir,
                               format: .flac, fileNameTemplate: "{title}.{output-ext}")
        #expect(p.format == .flac)
        #expect(p.fileNameTemplate == "{title}.{output-ext}")
    }

    @Test func playlistsGetDifferentIds() {
        let a = SyncedPlaylist(url: link, title: "A", outputDir: "/M", saveFileDirectory: saveDir,
                               format: .mp3, fileNameTemplate: DownloadOptions.defaultFileNameTemplate)
        let b = SyncedPlaylist(url: link, title: "A", outputDir: "/M", saveFileDirectory: saveDir,
                               format: .mp3, fileNameTemplate: DownloadOptions.defaultFileNameTemplate)
        #expect(a.id != b.id)
        #expect(a.saveFilePath != b.saveFilePath)
    }

    @Test func deleteRemovedCanBeTurnedOn() {
        let p = SyncedPlaylist(url: link, title: "Mix", outputDir: "/M", saveFileDirectory: saveDir,
                               format: .mp3, fileNameTemplate: DownloadOptions.defaultFileNameTemplate, deleteRemoved: true)
        #expect(p.deleteRemoved)
    }

    @Test(arguments: [
        ("https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M", true),
        ("https://open.spotify.com/album/4aawyAB9vmqN3uQ7FjRGTy", true),
        ("https://open.spotify.com/artist/0TnOYISbd1XYRBk9myaseg", true),
        ("https://open.spotify.com/track/6rqhFgbbKwnb9MLmUQDhG6", false),
        ("https://youtube.com/playlist?list=abc", false),
        ("daft punk", false),
        ("", false),
    ])
    func onlyListLinksCanSync(url: String, expected: Bool) {
        #expect(SyncedPlaylist.canSync(url) == expected)
    }

    @Test func codableRoundTrip() throws {
        var p = SyncedPlaylist(url: link, title: "Mix", outputDir: "/M", saveFileDirectory: saveDir,
                               format: .m4a, fileNameTemplate: "{title}.{output-ext}", deleteRemoved: true)
        p.lastSynced = Date(timeIntervalSince1970: 1_700_000_000)
        let decoded = try JSONDecoder().decode(SyncedPlaylist.self, from: JSONEncoder().encode(p))
        #expect(decoded == p)
    }

    @Test func iso8601RoundTrip() throws {
        var p = SyncedPlaylist(url: link, title: "Mix", outputDir: "/M", saveFileDirectory: saveDir,
                               format: .flac, fileNameTemplate: "{title}.{output-ext}", deleteRemoved: true)
        p.lastSynced = Date(timeIntervalSince1970: 1_700_000_000)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SyncedPlaylist.self, from: encoder.encode(p))
        #expect(decoded == p)
    }

    /// The shape written before format and fileNameTemplate existed.
    @Test func decodesAPlaylistSavedWithoutFormatOrTemplate() throws {
        let json = """
        {"id":"6F1C5C0B-3A7E-4B8E-9B3D-2D3E4F5A6B7C","url":"\(link)","title":"Mix","outputDir":"/M",
         "saveFilePath":"/sync/6F1C5C0B.spotdl","deleteRemoved":true,"lastSynced":700000000}
        """
        let p = try JSONDecoder().decode(SyncedPlaylist.self, from: Data(json.utf8))
        #expect(p.id.uuidString == "6F1C5C0B-3A7E-4B8E-9B3D-2D3E4F5A6B7C")
        #expect(p.url == link)
        #expect(p.title == "Mix")
        #expect(p.outputDir == "/M")
        #expect(p.saveFilePath == "/sync/6F1C5C0B.spotdl")
        #expect(p.format == .mp3)
        #expect(p.fileNameTemplate == DownloadOptions.defaultFileNameTemplate)
        #expect(p.deleteRemoved)
        #expect(p.lastSynced == Date(timeIntervalSinceReferenceDate: 700_000_000))
    }

    @Test func missingOptionalKeysUseDefaults() throws {
        let json = """
        {"id":"6F1C5C0B-3A7E-4B8E-9B3D-2D3E4F5A6B7C","url":"\(link)","title":"Mix","outputDir":"/M",
         "saveFilePath":"/sync/6F1C5C0B.spotdl"}
        """
        let p = try JSONDecoder().decode(SyncedPlaylist.self, from: Data(json.utf8))
        #expect(p.deleteRemoved == false)
        #expect(p.lastSynced == nil)
        #expect(p.format == .mp3)
    }

    @Test func missingRequiredKeyFails() {
        let json = #"{"url":"\#(link)","title":"Mix","outputDir":"/M","saveFilePath":"/sync/x.spotdl"}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(SyncedPlaylist.self, from: Data(json.utf8))
        }
    }
}
