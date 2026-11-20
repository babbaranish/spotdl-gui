import Testing

struct MatchFixTests {
    private let youtube = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    private let spotify = "https://open.spotify.com/track/6rqhFgbbKwnb9MLmUQDhG6"

    @Test(arguments: [
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        "https://youtube.com/watch?v=dQw4w9WgXcQ",
        "https://music.youtube.com/watch?v=dQw4w9WgXcQ",
        "https://m.youtube.com/watch?v=dQw4w9WgXcQ",
        "https://youtu.be/dQw4w9WgXcQ",
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42",
    ])
    func acceptsYouTubeLinks(link: String) {
        #expect(MatchFix.isYouTubeLink(link))
    }

    @Test(arguments: [
        "https://open.spotify.com/track/6rqhFgbbKwnb9MLmUQDhG6",
        "http://www.youtube.com/watch?v=dQw4w9WgXcQ",
        "https://www.youtube.com/watch?v=",
        "https://www.youtube.com/playlist?list=PL123",
        "https://youtu.be/",
        "https://example.com/watch?v=dQw4w9WgXcQ",
        "dQw4w9WgXcQ",
        "",
    ])
    func rejectsOtherLinks(link: String) {
        #expect(!MatchFix.isYouTubeLink(link))
    }

    @Test func spotifyTrackLinks() {
        #expect(MatchFix.isSpotifyTrackLink(spotify))
        #expect(MatchFix.isSpotifyTrackLink("https://open.spotify.com/track/abc?si=xyz"))
        #expect(!MatchFix.isSpotifyTrackLink("https://open.spotify.com/album/abc"))
        #expect(!MatchFix.isSpotifyTrackLink("https://www.youtube.com/watch?v=/track/"))
        #expect(!MatchFix.isSpotifyTrackLink("daft punk"))
    }

    @Test func combinesYouTubeAndSpotifyWithAPipe() {
        #expect(MatchFix.query(youtube: youtube, spotify: spotify) == "\(youtube)|\(spotify)")
    }

    @Test func trimsBothSides() {
        #expect(MatchFix.query(youtube: "  \(youtube)\n", spotify: " \(spotify) ") == "\(youtube)|\(spotify)")
    }

    @Test(arguments: [
        ("https://music.youtube.com/watch?v=dQw4w9WgXcQ&list=RDAMVMdQw4w9WgXcQ", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
        ("https://youtu.be/dQw4w9WgXcQ?list=PL123&index=2", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
        ("https://youtube.com/watch?v=dQw4w9WgXcQ&t=30", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
        ("https://youtube.com/watch?v=dQw4w9WgXcQ&si=abc123", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
    ])
    func rebuildsTheYouTubeLinkWithOnlyTheVideoID(link: String, expected: String) {
        #expect(MatchFix.query(youtube: link, spotify: spotify) == "\(expected)|\(spotify)")
    }

    @Test func invalidPartGivesNil() {
        #expect(MatchFix.query(youtube: "https://example.com", spotify: spotify) == nil)
        #expect(MatchFix.query(youtube: youtube, spotify: "https://open.spotify.com/album/abc") == nil)
        #expect(MatchFix.query(youtube: "", spotify: "") == nil)
    }

    @Test func resultIsATrackQuery() throws {
        let q = try #require(MatchFix.query(youtube: youtube, spotify: spotify))
        #expect(JobKind(query: q) == .track)
    }
}
