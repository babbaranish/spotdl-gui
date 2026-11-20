import AppKit
import SwiftUI

struct JobRow: View {
    @ObservedObject var job: Job
    private var showSongs: Bool { job.showSongs }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ArtworkView(job: job, size: 36, cornerRadius: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(job.title)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(job.query)
                    Text(job.statusLine)
                        .font(.subheadline)
                        .foregroundStyle(job.statusColor)
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

                JobActionsView(job: job)
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
                    SongListView(job: job)
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
        .fixMatchSheet(for: job)
    }

    private var songsLabel: String {
        let total = job.total ?? job.songs.count
        return "\(showSongs ? "Hide" : "Show") songs (\(job.finishedCount) of \(total) finished)"
    }
}
