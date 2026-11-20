import Foundation
import Testing

struct ArtworkTests {
    @Test func oEmbedURLEncodesTheLinkAsOneQueryValue() {
        let url = Artwork.oEmbedURL(for: "https://open.spotify.com/track/abc?si=x&y=z")
        #expect(url?.absoluteString
            == "https://open.spotify.com/oembed?url=https%3A%2F%2Fopen.spotify.com%2Ftrack%2Fabc%3Fsi%3Dx%26y%3Dz")
    }

    @Test func oEmbedURLNeedsASpotifyLink() {
        #expect(Artwork.oEmbedURL(for: "https://www.youtube.com/watch?v=x") == nil)
        #expect(Artwork.oEmbedURL(for: "http://open.spotify.com/track/a") == nil)
        #expect(Artwork.oEmbedURL(for: "daft punk") == nil)
    }

    @Test func parsesTheThumbnail() {
        let data = Data(#"{"title":"Song","thumbnail_url":"https://i.scdn.co/image/abc.jpeg","html":"<x>"}"#.utf8)
        #expect(Artwork.parseThumbnail(data) == URL(string: "https://i.scdn.co/image/abc.jpeg"))
    }

    @Test(arguments: [
        #"{"title":"Song"}"#,
        #"{"thumbnail_url":""}"#,
        #"{"thumbnail_url":5}"#,
        "not json",
        "[]",
    ])
    func missingOrBadThumbnailGivesNil(body: String) {
        #expect(Artwork.parseThumbnail(Data(body.utf8)) == nil)
    }
}
