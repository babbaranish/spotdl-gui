import Testing

struct JobKindTests {
    @Test(arguments: [
        ("https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M", JobKind.playlist),
        ("https://open.spotify.com/album/4aawyAB9vmqN3uQ7FjRGTy", .album),
        ("https://open.spotify.com/artist/0TnOYISbd1XYRBk9myaseg", .artist),
        ("https://open.spotify.com/track/6rqhFgbbKwnb9MLmUQDhG6", .track),
        ("HTTPS://OPEN.SPOTIFY.COM/PLAYLIST/ABC", .playlist),
        ("daft punk one more time", .search),
    ])
    func detectsKind(query: String, expected: JobKind) {
        #expect(JobKind(query: query) == expected)
    }

    @Test func listsUseTheirOwnFolder() {
        #expect(JobKind.album.usesFolder)
        #expect(JobKind.playlist.usesFolder)
        #expect(JobKind.artist.usesFolder)
        #expect(!JobKind.track.usesFolder)
        #expect(!JobKind.search.usesFolder)
    }
}
