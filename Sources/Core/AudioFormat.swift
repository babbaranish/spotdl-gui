import Foundation

enum AudioFormat: String, CaseIterable, Identifiable {
    case mp3, m4a, flac
    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
    var help: String {
        switch self {
        case .mp3: return "MP3 320 kbps. Plays everywhere."
        case .m4a: return "M4A, original audio with no re-encoding. Small files."
        case .flac: return "FLAC, lossless format. Larger files."
        }
    }
    var args: [String] {
        switch self {
        case .mp3: return ["--format", "mp3", "--bitrate", "320k"]
        case .m4a: return ["--format", "m4a", "--bitrate", "disable"]
        case .flac: return ["--format", "flac"]
        }
    }
}
