import Foundation

enum JobKind {
    case track, album, playlist, artist, search

    init(query: String) {
        let q = query.lowercased()
        if q.contains("/playlist/") { self = .playlist }
        else if q.contains("/album/") { self = .album }
        else if q.contains("/artist/") { self = .artist }
        else if q.contains("/track/") { self = .track }
        else { self = .search }
    }

    var symbol: String {
        switch self {
        case .track: return "music.note"
        case .album: return "square.stack"
        case .playlist: return "music.note.list"
        case .artist: return "music.mic"
        case .search: return "magnifyingglass"
        }
    }

    var placeholderTitle: String {
        switch self {
        case .track: return "Spotify song"
        case .album: return "Spotify album"
        case .playlist: return "Spotify playlist"
        case .artist: return "Spotify artist"
        case .search: return ""
        }
    }

    /// Lists get their own folder; single songs go straight into the output folder.
    var usesFolder: Bool { self == .album || self == .playlist || self == .artist }
}
