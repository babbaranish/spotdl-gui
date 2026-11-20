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
        #expect(SpotDLCommand.arguments(query: q, kind: .track, format: .mp3) == [
            "download", q, "--format", "mp3", "--bitrate", "320k",
            "--output", "{artists} - {title}.{output-ext}", "--simple-tui",
        ])
        #expect(SpotDLCommand.arguments(query: q, kind: .track, format: .m4a) == [
            "download", q, "--format", "m4a", "--bitrate", "disable",
            "--output", "{artists} - {title}.{output-ext}", "--simple-tui",
        ])
        #expect(SpotDLCommand.arguments(query: q, kind: .playlist, format: .flac) == [
            "download", q, "--format", "flac",
            "--output", "{list-name}/{artists} - {title}.{output-ext}", "--simple-tui",
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
