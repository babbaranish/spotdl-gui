import Foundation
import Testing

struct DownloadOptionsTests {
    private func roundTrip<T: Codable>(_ value: T) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
    }

    @Test func defaultsMatchSpotDLDefaults() {
        let o = DownloadOptions()
        #expect(o.format == .mp3)
        #expect(!o.syncedLyrics)
        #expect(o.audioSource == .youtubeMusic)
        #expect(o.cookieFile == nil)
        #expect(o.fileNameTemplate == "{artists} - {title}.{output-ext}")
        #expect(o.extraArguments.isEmpty)
    }

    @Test(arguments: [
        "{artists} - {title}.{output-ext}",
        "{title}.{output-ext}",
        "{title} [{album}].{output-ext}",
    ])
    func validTemplates(template: String) {
        #expect(DownloadOptions.isValidTemplate(template))
    }

    @Test(arguments: [
        "{artists}.{output-ext}",
        "{title}",
        "{title}/{artists}.{output-ext}",
        "{title}.mp3/x",
        "{title}{output-ext}",
        "{title}.{output-ext} copy",
        "",
        "   ",
    ])
    func invalidTemplates(template: String) {
        #expect(!DownloadOptions.isValidTemplate(template))
    }

    @Test func effectiveTemplateFallsBackToDefault() {
        var o = DownloadOptions()
        o.fileNameTemplate = "{title}.{output-ext}"
        #expect(o.effectiveTemplate == "{title}.{output-ext}")
        o.fileNameTemplate = "{title}/x.{output-ext}"
        #expect(o.effectiveTemplate == DownloadOptions.defaultFileNameTemplate)
    }

    @Test func extraArgumentsAreEmptyByDefault() {
        #expect(DownloadOptions().extraArguments.isEmpty)
    }

    @Test func syncedLyricsAddsTheFlag() {
        #expect(DownloadOptions(syncedLyrics: true).extraArguments == ["--generate-lrc"])
    }

    @Test func nonDefaultSourceAddsTheAudioFlag() {
        #expect(DownloadOptions(audioSource: .youtube).extraArguments == ["--audio", "youtube"])
        #expect(DownloadOptions(audioSource: .soundcloud).extraArguments == ["--audio", "soundcloud"])
        #expect(DownloadOptions(audioSource: .piped).extraArguments == ["--audio", "piped"])
    }

    @Test func cookieFileAddsItsPath() {
        #expect(DownloadOptions(cookieFile: "/Users/x/cookies.txt").extraArguments == ["--cookie-file", "/Users/x/cookies.txt"])
    }

    @Test(arguments: [nil, "", "   "] as [String?])
    func blankCookieFileIsOmitted(path: String?) {
        #expect(DownloadOptions(cookieFile: path).extraArguments.isEmpty)
    }

    @Test func extraArgumentsKeepTheirOrder() {
        let o = DownloadOptions(syncedLyrics: true, audioSource: .piped, cookieFile: "/c.txt")
        #expect(o.extraArguments == ["--generate-lrc", "--audio", "piped", "--cookie-file", "/c.txt"])
    }

    @Test func audioSourceLabelsAndRawValues() {
        #expect(AudioSource.allCases.map(\.rawValue) == ["youtube-music", "youtube", "soundcloud", "bandcamp", "piped"])
        #expect(AudioSource.allCases.map(\.label) == ["YouTube Music", "YouTube", "SoundCloud", "Bandcamp", "Piped"])
        #expect(AudioSource.youtubeMusic.id == "youtube-music")
    }

    @Test func audioFormatEncodesAsItsRawValue() throws {
        #expect(String(data: try JSONEncoder().encode(AudioFormat.flac), encoding: .utf8) == "\"flac\"")
        #expect(try roundTrip(AudioFormat.m4a) == .m4a)
    }

    @Test func emptyJSONDecodesToDefaults() throws {
        #expect(try JSONDecoder().decode(DownloadOptions.self, from: Data("{}".utf8)) == DownloadOptions())
    }

    @Test func missingKeysKeepTheirDefaults() throws {
        let o = try JSONDecoder().decode(DownloadOptions.self, from: Data(#"{"format":"flac"}"#.utf8))
        #expect(o == DownloadOptions(format: .flac))
    }

    @Test func optionsRoundTripThroughJSON() throws {
        let o = DownloadOptions(format: .flac, syncedLyrics: true, audioSource: .bandcamp,
                                cookieFile: "/c.txt", fileNameTemplate: "{title}.{output-ext}")
        #expect(try roundTrip(o) == o)
    }
}
