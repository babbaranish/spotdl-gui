import Testing

struct QueryInputTests {
    @Test func emptyInputGivesNothing() {
        #expect(QueryInput.queries(from: "") == [])
        #expect(QueryInput.queries(from: "  \n\t ") == [])
    }

    @Test func searchTextStaysOneQuery() {
        #expect(QueryInput.queries(from: "  daft punk one more time \n") == ["daft punk one more time"])
    }

    @Test func singleLinkIsTrimmed() {
        #expect(QueryInput.queries(from: " https://open.spotify.com/track/a\n") == ["https://open.spotify.com/track/a"])
    }

    @Test func severalLinksAreSplitOnSpacesAndNewLines() {
        let text = "https://open.spotify.com/track/a https://open.spotify.com/album/b\nhttps://open.spotify.com/playlist/c"
        #expect(QueryInput.queries(from: text) == [
            "https://open.spotify.com/track/a",
            "https://open.spotify.com/album/b",
            "https://open.spotify.com/playlist/c",
        ])
    }

    @Test func linkMixedWithTextStaysOneQuery() {
        #expect(QueryInput.queries(from: "https://open.spotify.com/track/a please") == ["https://open.spotify.com/track/a please"])
    }

    @Test func spotifyLinkDetection() {
        #expect(QueryInput.isSpotifyLink("https://open.spotify.com/track/a"))
        #expect(!QueryInput.isSpotifyLink("http://open.spotify.com/track/a"))
        #expect(!QueryInput.isSpotifyLink("https://youtube.com/watch?v=x"))
        #expect(!QueryInput.isSpotifyLink("daft punk"))
    }
}
