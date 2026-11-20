import Foundation

enum AudioSource: String, CaseIterable, Identifiable, Codable {
    case youtubeMusic = "youtube-music", youtube, soundcloud, bandcamp, piped
    var id: String { rawValue }
    var label: String {
        switch self {
        case .youtubeMusic: return "YouTube Music"
        case .youtube: return "YouTube"
        case .soundcloud: return "SoundCloud"
        case .bandcamp: return "Bandcamp"
        case .piped: return "Piped"
        }
    }
}

/// Settings that change how spotDL downloads. Stored as JSON in the app's settings.
struct DownloadOptions: Equatable, Codable {
    static let defaultFileNameTemplate = "{artists} - {title}.{output-ext}"

    var format: AudioFormat = .mp3
    var syncedLyrics = false                      // --generate-lrc
    var audioSource: AudioSource = .youtubeMusic  // spotDL's default; flag only passed when different
    var cookieFile: String? = nil                 // --cookie-file, omitted when nil or blank
    var fileNameTemplate = DownloadOptions.defaultFileNameTemplate

    private enum CodingKeys: String, CodingKey {
        case format, syncedLyrics, audioSource, cookieFile, fileNameTemplate
    }

    /// Valid when it contains "{title}", ends with ".{output-ext}" and has no "/" (folders are the app's job).
    static func isValidTemplate(_ t: String) -> Bool {
        t.contains("{title}") && t.hasSuffix(".{output-ext}") && !t.contains("/")
    }

    /// fileNameTemplate if valid, otherwise the default.
    var effectiveTemplate: String {
        Self.isValidTemplate(fileNameTemplate) ? fileNameTemplate : Self.defaultFileNameTemplate
    }

    /// Extra spotDL flags for these options, in this order:
    /// ["--generate-lrc"] if syncedLyrics; ["--audio", raw] if not youtubeMusic; ["--cookie-file", path] if set.
    var extraArguments: [String] {
        var args: [String] = []
        if syncedLyrics { args.append("--generate-lrc") }
        if audioSource != .youtubeMusic { args += ["--audio", audioSource.rawValue] }
        if let cookieFile, !cookieFile.trimmingCharacters(in: .whitespaces).isEmpty {
            args += ["--cookie-file", cookieFile]
        }
        return args
    }
}

extension DownloadOptions {
    /// Every key is optional so older settings files still load; missing keys take the defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = try c.decodeIfPresent(AudioFormat.self, forKey: .format) ?? .mp3
        syncedLyrics = try c.decodeIfPresent(Bool.self, forKey: .syncedLyrics) ?? false
        audioSource = try c.decodeIfPresent(AudioSource.self, forKey: .audioSource) ?? .youtubeMusic
        cookieFile = try c.decodeIfPresent(String.self, forKey: .cookieFile)
        fileNameTemplate = try c.decodeIfPresent(String.self, forKey: .fileNameTemplate)
            ?? DownloadOptions.defaultFileNameTemplate
    }
}
