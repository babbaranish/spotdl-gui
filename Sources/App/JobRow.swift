import AppKit
import SwiftUI

struct JobRow: View {
    @ObservedObject var job: Job
    @EnvironmentObject var dl: Downloader
    @ObservedObject private var syncStore = SyncStore.shared
    private var showSongs: Bool { job.showSongs }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.15))
                    if let url = job.artworkURL {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            kindSymbol
                        }
                    } else {
                        kindSymbol
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(job.title)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(job.query)
                    Text(statusLine)
                        .font(.subheadline)
                        .foregroundStyle(statusColor)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                if job.syncedPlaylist != nil {
                    Text("Synced")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.green.opacity(0.15)))
                        .help("Kept in sync with the Spotify list")
                }

                Text(job.format.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))

                actions
            }

            if job.state == .fetching || job.state == .downloading {
                if let p = job.progress, job.state == .downloading {
                    ProgressView(value: p)
                } else {
                    ProgressView().progressViewStyle(.linear)
                }
                if let current = job.currentSong {
                    Text("Now: \(current)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            if case .failed(let message) = job.state {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            if job.songs.count > 1 || job.failedCount > 0 {
                DisclosureGroup(isExpanded: $job.showSongs) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(job.songs) { song in
                                SongLine(song: song, onFix: fixAction(for: song))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 220)
                } label: {
                    Text(songsLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation { job.showSongs.toggle() } }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(nsColor: .separatorColor).opacity(0.6)))
        .sheet(isPresented: fixSheetShown) {
            FixMatchSheet(
                songName: job.fixingSong ?? "",
                knownSpotifyLink: knownSpotifyLink,
                onSubmit: { query in dl.fixMatch(in: job, query: query) },
                onCancel: { job.fixingSong = nil }
            )
        }
    }

    private var kindSymbol: some View {
        Image(systemName: job.kind.symbol).foregroundStyle(tint)
    }

    private var fixSheetShown: Binding<Bool> {
        Binding(
            get: { job.fixingSong != nil },
            set: { if !$0 { job.fixingSong = nil } }
        )
    }

    /// A song job's own link is the Spotify song, so the sheet only asks for it on lists and searches.
    private var knownSpotifyLink: String? {
        job.kind == .track && MatchFix.isSpotifyTrackLink(job.query) ? job.query : nil
    }

    private func fixAction(for song: SongRow) -> (() -> Void)? {
        guard song.state == .failed, job.isFinished else { return nil }
        return { job.fixingSong = song.name }
    }

    /// Album, playlist and artist downloads that are not synced yet.
    private var canKeepInSync: Bool {
        job.syncedPlaylist == nil && SyncedPlaylist.canSync(job.query) && !syncStore.contains(url: job.query)
    }

    @ViewBuilder private var actions: some View {
        switch job.state {
        case .waiting, .fetching, .downloading:
            Button("Cancel") { dl.cancel(job) }
                .controlSize(.small)
        case .done:
            Button("Show in Finder") { job.reveal() }
                .controlSize(.small)
            moreMenu
            removeButton
        case .failed, .cancelled:
            Button("Retry") { dl.retry(job) }
                .controlSize(.small)
            removeButton
        }
    }

    private var moreMenu: some View {
        Menu {
            Button("Add to Music") {
                if !MusicLibrary.add(job.savedFiles) { NSSound.beep() }
            }
            if canKeepInSync {
                Button("Keep in sync") { dl.keepInSync(job) }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(.secondary)
        .help("More")
    }

    private var removeButton: some View {
        Button { withAnimation { dl.remove(job) } } label: {
            Image(systemName: "xmark").font(.caption.weight(.semibold))
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help("Remove from list")
    }

    private var tint: Color {
        switch job.state {
        case .done: return job.failedCount > 0 ? .orange : .green
        case .failed: return .red
        case .cancelled: return .secondary
        default: return .accentColor
        }
    }

    private var statusColor: Color {
        switch job.state {
        case .failed: return .red
        case .done where job.failedCount > 0: return .orange
        default: return .secondary
        }
    }

    private var statusLine: String {
        switch job.state {
        case .waiting:
            return "Waiting in line"
        case .fetching where job.rateLimited:
            return "Spotify is rate limiting. Still trying, or cancel and retry later."
        case .fetching:
            return job.kind.usesFolder ? "Finding songs… (big playlists take a minute)" : "Finding song…"
        case .downloading:
            if let total = job.total, total > 1 {
                return "Downloading \(job.finishedCount) of \(total)"
            }
            return "Downloading…"
        case .done:
            let summary = job.doneSummary
            if summary.isEmpty { return "Done" }
            // Only the single-song results stand alone; the rest read like "Done: 12 saved, 1 failed".
            return summary == "Downloaded" || summary == "Already downloaded" ? summary : "Done: " + summary
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        }
    }

    private var songsLabel: String {
        let total = job.total ?? job.songs.count
        return "\(showSongs ? "Hide" : "Show") songs (\(job.finishedCount) of \(total) finished)"
    }
}
