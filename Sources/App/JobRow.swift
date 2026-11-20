import SwiftUI

struct JobRow: View {
    @ObservedObject var job: Job
    @EnvironmentObject var dl: Downloader
    private var showSongs: Bool { job.showSongs }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.15))
                    Image(systemName: job.kind.symbol).foregroundStyle(tint)
                }
                .frame(width: 36, height: 36)

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
                            ForEach(job.songs) { SongLine(song: $0) }
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
    }

    @ViewBuilder private var actions: some View {
        switch job.state {
        case .waiting, .fetching, .downloading:
            Button("Cancel") { dl.cancel(job) }
                .controlSize(.small)
        case .done:
            Button("Show in Finder") { job.reveal() }
                .controlSize(.small)
            removeButton
        case .failed, .cancelled:
            Button("Retry") { dl.retry(job) }
                .controlSize(.small)
            removeButton
        }
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
            var parts: [String] = []
            let saved = job.doneCount
            if saved > 0 { parts.append(saved == 1 && job.songs.count == 1 ? "Saved" : "\(saved) saved") }
            if job.skippedCount > 0 { parts.append("\(job.skippedCount) already downloaded") }
            if job.failedCount > 0 { parts.append("\(job.failedCount) failed") }
            if job.songs.count == 1 && job.doneCount == 1 { return "Downloaded" }
            if job.songs.count == 1 && job.skippedCount == 1 { return "Already downloaded" }
            if parts.isEmpty { return "Done" }
            return "Done: " + parts.joined(separator: ", ")
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
