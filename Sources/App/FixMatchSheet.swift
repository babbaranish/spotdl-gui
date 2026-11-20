import SwiftUI

/// Holds the two links typed into FixMatchSheet.
@MainActor
final class FixMatchModel: ObservableObject {
    @Published var youtube = ""
    @Published var spotify = ""
}

/// Asks for the right YouTube link for a song that downloaded the wrong match.
struct FixMatchSheet: View {
    let songName: String
    let knownSpotifyLink: String?
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @StateObject private var ui = FixMatchModel()

    private var spotifyLink: String { knownSpotifyLink ?? ui.spotify }
    private var query: String? { MatchFix.query(youtube: ui.youtube, spotify: spotifyLink) }
    private var youtubeLooksWrong: Bool {
        let link = ui.youtube.trimmingCharacters(in: .whitespacesAndNewlines)
        return !link.isEmpty && !MatchFix.isYouTubeLink(link)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Fix this song")
                    .font(.headline)
                Text(songName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            VStack(alignment: .leading, spacing: 4) {
                TextField("YouTube link", text: $ui.youtube)
                    .textFieldStyle(.roundedBorder)
                    .help("Find the right version on YouTube or YouTube Music and copy its link")
                if youtubeLooksWrong {
                    Text("Paste a link to one YouTube video.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if knownSpotifyLink == nil {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Spotify song link", text: $ui.spotify)
                        .textFieldStyle(.roundedBorder)
                        .help("Copy the link to the song in Spotify")
                    Text("Use a link to a single song, not an album or playlist.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Download") {
                    if let query { onSubmit(query) }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(query == nil)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
