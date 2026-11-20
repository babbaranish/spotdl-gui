import Foundation
import Testing

struct SpotDLCommandTests {
    @Test func singleSongsGoStraightIntoTheFolder() {
        #expect(SpotDLCommand.outputTemplate(for: .track) == "{artists} - {title}.{output-ext}")
        #expect(SpotDLCommand.outputTemplate(for: .search) == "{artists} - {title}.{output-ext}")
    }

    @Test func listsGetASubfolder() {
        #expect(SpotDLCommand.outputTemplate(for: .playlist) == "{list-name}/{artists} - {title}.{output-ext}")
        #expect(SpotDLCommand.outputTemplate(for: .album) == "{list-name}/{artists} - {title}.{output-ext}")
    }

    @Test func argumentsPerFormat() {
        let q = "https://open.spotify.com/track/a"
        #expect(SpotDLCommand.arguments(query: q, kind: .track, options: DownloadOptions(format: .mp3)) == [
            "download", q, "--format", "mp3", "--bitrate", "320k",
            "--output", "{artists} - {title}.{output-ext}", "--simple-tui",
        ])
        #expect(SpotDLCommand.arguments(query: q, kind: .track, options: DownloadOptions(format: .m4a)) == [
            "download", q, "--format", "m4a", "--bitrate", "disable",
            "--output", "{artists} - {title}.{output-ext}", "--simple-tui",
        ])
        #expect(SpotDLCommand.arguments(query: q, kind: .playlist, options: DownloadOptions(format: .flac)) == [
            "download", q, "--format", "flac",
            "--output", "{list-name}/{artists} - {title}.{output-ext}", "--simple-tui",
        ])
    }

    @Test func optionFlagsComeBeforeSimpleTui() {
        let q = "https://open.spotify.com/album/a"
        let options = DownloadOptions(format: .mp3, syncedLyrics: true, audioSource: .soundcloud,
                                      cookieFile: "/c.txt", fileNameTemplate: "{title}.{output-ext}")
        #expect(SpotDLCommand.arguments(query: q, kind: .album, options: options) == [
            "download", q, "--format", "mp3", "--bitrate", "320k",
            "--output", "{list-name}/{title}.{output-ext}",
            "--generate-lrc", "--audio", "soundcloud", "--cookie-file", "/c.txt", "--simple-tui",
        ])
    }

    @Test func invalidTemplateFallsBackToTheDefault() {
        let q = "https://open.spotify.com/track/a"
        let options = DownloadOptions(fileNameTemplate: "{title}/x.{output-ext}")
        #expect(SpotDLCommand.arguments(query: q, kind: .track, options: options) == [
            "download", q, "--format", "mp3", "--bitrate", "320k",
            "--output", "{artists} - {title}.{output-ext}", "--simple-tui",
        ])
    }

    @Test func outputTemplateTakesAFileName() {
        #expect(SpotDLCommand.outputTemplate(for: .track, fileName: "{title}.{output-ext}") == "{title}.{output-ext}")
        #expect(SpotDLCommand.outputTemplate(for: .playlist, fileName: "{title}.{output-ext}") == "{list-name}/{title}.{output-ext}")
        #expect(SpotDLCommand.outputTemplate(for: .track) == DownloadOptions.defaultFileNameTemplate)
    }

    private let syncURL = "https://open.spotify.com/playlist/abc"
    private let syncDir = URL(fileURLWithPath: "/sync")

    private func syncPlaylist(format: AudioFormat = .mp3, template: String = DownloadOptions.defaultFileNameTemplate,
                              deleteRemoved: Bool = false) -> SyncedPlaylist {
        SyncedPlaylist(url: syncURL, title: "Mix", outputDir: "/Music", saveFileDirectory: syncDir,
                       format: format, fileNameTemplate: template, deleteRemoved: deleteRemoved)
    }

    @Test func firstSyncSavesTheFile() {
        let playlist = syncPlaylist()
        #expect(SpotDLCommand.syncArguments(playlist: playlist, saveFileExists: false, options: DownloadOptions()) == [
            "sync", playlist.url, "--save-file", playlist.saveFilePath,
            "--format", "mp3", "--bitrate", "320k",
            "--output", "{list-name}/{artists} - {title}.{output-ext}",
            "--sync-without-deleting", "--simple-tui",
        ])
    }

    @Test func firstSyncWithDeleteRemovedStillSavesTheFile() {
        let playlist = syncPlaylist(deleteRemoved: true)
        let args = SpotDLCommand.syncArguments(playlist: playlist, saveFileExists: false, options: DownloadOptions())
        #expect(args.prefix(4) == ["sync", syncURL, "--save-file", playlist.saveFilePath])
        #expect(!args.contains("--sync-without-deleting"))
        #expect(args.last == "--simple-tui")
    }

    @Test func laterSyncReadsTheSaveFile() {
        let playlist = syncPlaylist(deleteRemoved: true)
        #expect(SpotDLCommand.syncArguments(playlist: playlist, saveFileExists: true, options: DownloadOptions()) == [
            "sync", playlist.saveFilePath,
            "--format", "mp3", "--bitrate", "320k",
            "--output", "{list-name}/{artists} - {title}.{output-ext}",
            "--simple-tui",
        ])
    }

    @Test func syncUsesThePlaylistsFormatNotTheGlobalOne() {
        let playlist = syncPlaylist(format: .flac)
        let args = SpotDLCommand.syncArguments(playlist: playlist, saveFileExists: true, options: DownloadOptions(format: .m4a))
        #expect(args.contains("flac"))
        #expect(!args.contains("m4a"))
        #expect(!args.contains("--bitrate"))
    }

    @Test func syncUsesThePlaylistsTemplateNotTheGlobalOne() {
        let playlist = syncPlaylist(template: "{title}.{output-ext}")
        let options = DownloadOptions(fileNameTemplate: "{artists}/{title}.{output-ext}")
        #expect(SpotDLCommand.syncArguments(playlist: playlist, saveFileExists: true, options: options) == [
            "sync", playlist.saveFilePath,
            "--format", "mp3", "--bitrate", "320k",
            "--output", "{list-name}/{title}.{output-ext}",
            "--sync-without-deleting", "--simple-tui",
        ])
    }

    @Test func syncFallsBackToTheDefaultWhenThePlaylistTemplateIsInvalid() {
        let playlist = syncPlaylist(template: "{title}")
        let options = DownloadOptions(fileNameTemplate: "{title}.{output-ext}")
        let args = SpotDLCommand.syncArguments(playlist: playlist, saveFileExists: true, options: options)
        #expect(args.contains("{list-name}/{artists} - {title}.{output-ext}"))
    }

    @Test func syncRemoveLrcOnlyWhenDeletingAndSyncedLyrics() {
        let combos: [(deleteRemoved: Bool, lyrics: Bool, expected: Bool)] = [
            (true, true, true), (true, false, false), (false, true, false), (false, false, false),
        ]
        for c in combos {
            let playlist = syncPlaylist(deleteRemoved: c.deleteRemoved)
            let options = DownloadOptions(syncedLyrics: c.lyrics)
            let args = SpotDLCommand.syncArguments(playlist: playlist, saveFileExists: true, options: options)
            #expect(args.contains("--sync-remove-lrc") == c.expected)
            #expect(args.contains("--generate-lrc") == c.lyrics)
        }
    }

    @Test func syncRemoveLrcTakesThePlaceOfWithoutDeleting() {
        let playlist = syncPlaylist(deleteRemoved: true)
        let args = SpotDLCommand.syncArguments(playlist: playlist, saveFileExists: true,
                                               options: DownloadOptions(syncedLyrics: true))
        #expect(args == [
            "sync", playlist.saveFilePath,
            "--format", "mp3", "--bitrate", "320k",
            "--output", "{list-name}/{artists} - {title}.{output-ext}",
            "--generate-lrc", "--sync-remove-lrc",
            "--simple-tui",
        ])
    }

    @Test func syncPassesTheOptionFlags() {
        let playlist = SyncedPlaylist(url: "https://open.spotify.com/album/abc", title: "Album",
                                      outputDir: "/Music", saveFileDirectory: syncDir,
                                      format: .mp3, fileNameTemplate: "{title}.{output-ext}", deleteRemoved: true)
        let options = DownloadOptions(cookieFile: "/c.txt", fileNameTemplate: "{artists}.{output-ext}")
        #expect(SpotDLCommand.syncArguments(playlist: playlist, saveFileExists: true, options: options) == [
            "sync", playlist.saveFilePath,
            "--format", "mp3", "--bitrate", "320k",
            "--output", "{list-name}/{title}.{output-ext}",
            "--cookie-file", "/c.txt",
            "--simple-tui",
        ])
    }

    @Test func environmentKeepsBaseAndForcesPlainOutput() {
        let env = SpotDLCommand.environment(base: ["HOME": "/Users/x", "PATH": "/usr/bin"], home: "/Users/x")
        #expect(env["HOME"] == "/Users/x")
        #expect(env["PATH"] == "/opt/homebrew/bin:/usr/local/bin:/Users/x/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin")
        #expect(env["COLUMNS"] == "1000")
        #expect(env["PYTHONUNBUFFERED"] == "1")
        #expect(env["NO_COLOR"] == "1")
        #expect(env["TERM"] == "dumb")
    }

    @Test func candidatePathsInSearchOrder() {
        #expect(SpotDLCommand.candidatePaths(home: "/Users/x") == [
            "/Users/x/.local/bin/spotdl", "/opt/homebrew/bin/spotdl", "/usr/local/bin/spotdl",
        ])
    }

    @Test(arguments: [
        ("Grand Theft Auto VI: The Album", "Grand Theft Auto VI- The Album"),
        ("AC/DC  Live?  \"Best\"", "ACDC Live 'Best'"),
        ("a|b<c>d*e\\f", "abcdef"),
        ("Plain Name", "Plain Name"),
    ])
    func sanitizeMirrorsSpotDL(input: String, expected: String) {
        #expect(SpotDLCommand.sanitize(input) == expected)
    }
}
