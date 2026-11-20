import Foundation

/// Cover art for a Spotify link, from Spotify's public oEmbed endpoint.
enum Artwork {
    /// https://open.spotify.com/oembed?url=<link percent-encoded as a query value>; nil unless QueryInput.isSpotifyLink.
    static func oEmbedURL(for link: String) -> URL? {
        guard QueryInput.isSpotifyLink(link) else { return nil }
        // Only unreserved characters stay as they are, so "?", "=", "&" and "/" in the link are escaped too.
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        guard let encoded = link.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "https://open.spotify.com/oembed?url=\(encoded)")
    }

    /// "thumbnail_url" from oEmbed JSON; nil if missing or invalid.
    static func parseThumbnail(_ data: Data) -> URL? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let thumbnail = json["thumbnail_url"] as? String
        else { return nil }
        return URL(string: thumbnail)
    }
}
