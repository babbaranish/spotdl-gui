import Foundation

enum QueryInput {
    /// One search term, or one or more links separated by spaces/new lines.
    static func queries(from text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let parts = trimmed.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        return parts.count > 1 && parts.allSatisfy({ $0.hasPrefix("http") }) ? parts : [trimmed]
    }

    static func isSpotifyLink(_ s: String) -> Bool {
        s.hasPrefix("https://open.spotify.com/")
    }
}
