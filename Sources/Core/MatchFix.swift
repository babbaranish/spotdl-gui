import Foundation

/// Checks the two links used to fix a song that downloaded the wrong match.
enum MatchFix {
    /// https://(www.|music.|m.)youtube.com/watch?v=..., https://youtube.com/watch?v=..., https://youtu.be/...
    static func isYouTubeLink(_ s: String) -> Bool {
        s.wholeMatch(of: #/https:\/\/((www|music|m)\.)?youtube\.com\/watch\?v=[A-Za-z0-9_-]+(&\S*)?/#) != nil
            || s.wholeMatch(of: #/https:\/\/youtu\.be\/[A-Za-z0-9_-]+(\?\S*)?/#) != nil
    }

    /// Spotify link containing "/track/".
    static func isSpotifyTrackLink(_ s: String) -> Bool {
        QueryInput.isSpotifyLink(s) && s.lowercased().contains("/track/")
    }

    /// The video ID from a link that passed isYouTubeLink.
    private static func videoID(_ link: String) -> String? {
        if let m = link.firstMatch(of: #/youtube\.com\/watch\?v=([A-Za-z0-9_-]+)/#) { return String(m.1) }
        if let m = link.firstMatch(of: #/youtu\.be\/([A-Za-z0-9_-]+)/#) { return String(m.1) }
        return nil
    }

    /// "https://www.youtube.com/watch?v=<id>|<spotify>" (both trimmed; the YouTube link keeps only the
    /// video ID, so list=, index=, si= and t= are dropped) or nil if either is invalid.
    static func query(youtube: String, spotify: String) -> String? {
        let y = youtube.trimmingCharacters(in: .whitespacesAndNewlines)
        let s = spotify.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isYouTubeLink(y), let id = videoID(y), isSpotifyTrackLink(s) else { return nil }
        return "https://www.youtube.com/watch?v=\(id)|\(s)"
    }
}
