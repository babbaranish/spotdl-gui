import Foundation

/// Cover art URLs for Spotify links, from Spotify's oEmbed endpoint. Successful lookups are cached in memory.
@MainActor
enum ArtworkLoader {
    private static var cache: [String: URL] = [:]

    /// nil when the link is not Spotify, the request fails or the answer has no thumbnail.
    static func fetch(for link: String) async -> URL? {
        if let cached = cache[link] { return cached }
        guard let endpoint = Artwork.oEmbedURL(for: link) else { return nil }
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 10
        guard let result = try? await URLSession.shared.data(for: request),
              (result.1 as? HTTPURLResponse)?.statusCode == 200,
              let url = Artwork.parseThumbnail(result.0)
        else { return nil }
        cache[link] = url
        return url
    }
}
