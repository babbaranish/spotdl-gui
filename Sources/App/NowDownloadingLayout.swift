import SwiftUI

/// A big card for the job running now, the queue under it and the finished jobs at the bottom.
struct NowDownloadingLayout: View {
    let ctx: LayoutContext
    @EnvironmentObject var dl: Downloader

    /// The running job, else the oldest waiting one (jobs are newest first, so that is the last waiting job).
    private var current: Job? {
        dl.jobs.first { $0.state == .fetching || $0.state == .downloading }
            ?? dl.jobs.last { $0.state == .waiting }
    }

    private var upNext: [Job] {
        dl.jobs.filter { $0.state == .waiting && $0.id != current?.id }.reversed()
    }

    private var finished: [Job] {
        dl.jobs.filter { !$0.state.isActive }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            if dl.jobs.isEmpty {
                EmptyJobsView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let current {
                            HeroCard(job: current)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 4)
                        }
                        if !upNext.isEmpty {
                            sectionHeader("Up next")
                            ForEach(upNext) { CompactJobRow(job: $0) }
                        }
                        if !finished.isEmpty {
                            sectionHeader("Finished")
                            ForEach(finished) { CompactJobRow(job: $0) }
                        }
                    }
                    .padding(.bottom, 12)
                }
                .animation(.snappy, value: dl.jobs.map(\.id))
            }
            Divider()
            footer
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            QueryField(ctx: ctx)
            FormatPicker(style: .menu)
                .fixedSize()
            DownloadButton(ctx: ctx, large: false)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 6)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            SavingToView()
            Spacer()
            Button("Synced playlists", action: ctx.showSyncList)
                .buttonStyle(.borderless)
                .help("Playlists, albums and artists kept up to date")
            if dl.hasFinished {
                Button("Clear finished") { withAnimation { dl.clearFinished() } }
                    .buttonStyle(.borderless)
            }
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .frame(height: 34)
    }
}

/// The running (or next) job as a large card. Cover art, progress and its song list sit on a blurred copy of the art.
private struct HeroCard: View {
    @ObservedObject var job: Job

    init(job: Job) {
        _job = ObservedObject(wrappedValue: job)
    }

    private var caption: String {
        switch job.state {
        case .waiting: return "Up next"
        case .fetching: return "Finding songs"
        default: return "Downloading " + kindWord
        }
    }

    /// The lowercase kind word for the caption. Single-song searches count as songs.
    private var kindWord: String {
        switch job.kind {
        case .track, .search: return "song"
        case .album: return "album"
        case .playlist: return "playlist"
        case .artist: return "artist"
        }
    }

    private var formatLine: String {
        var line = job.format.label
        if let total = job.total, total > 1 {
            line += " · \(total) songs"
        }
        return line
    }

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            ArtworkView(job: job, size: 132, cornerRadius: 12)
                .shadow(radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 6) {
                Text(caption)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.75))
                Text(job.title)
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .help(job.query)
                Text(formatLine)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))

                Spacer(minLength: 6)

                progressBar
                HStack(spacing: 8) {
                    Text(job.currentSong.map { "Now: \($0)" } ?? job.statusLine)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 8)
                    JobActionsView(job: job)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !job.songs.isEmpty {
                SongListView(job: job, maxHeight: 132)
                    .padding(10)
                    .frame(width: 240)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.25)))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .environment(\.colorScheme, .dark)
        .background { heroBackground }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .fixMatchSheet(for: job)
    }

    @ViewBuilder
    private var progressBar: some View {
        if job.state == .downloading, let progress = job.progress {
            ProgressView(value: progress)
                .tint(.green)
        } else {
            ProgressView()
                .progressViewStyle(.linear)
                .tint(.green)
        }
    }

    @ViewBuilder
    private var heroBackground: some View {
        if let url = job.artworkURL {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 40)
                    .saturation(1.3)
                    .overlay(Color.black.opacity(0.45))
            } placeholder: {
                tintGradient
            }
        } else {
            tintGradient
        }
    }

    /// Always dark, so the white text stays readable in light mode too.
    private var tintGradient: some View {
        ZStack {
            Color(white: 0.14)
            LinearGradient(colors: [job.tint.opacity(0.55), .clear],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

/// One job in the queue or the finished list. Its songs open under it.
private struct CompactJobRow: View {
    @ObservedObject var job: Job

    init(job: Job) {
        _job = ObservedObject(wrappedValue: job)
    }

    private var canShowSongs: Bool {
        job.songs.count > 1 || job.failedCount > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ArtworkView(job: job, size: 32, cornerRadius: 6)

                VStack(alignment: .leading, spacing: 1) {
                    Text(job.title)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(job.query)
                    Text(job.statusLine)
                        .font(.caption)
                        .foregroundStyle(job.statusColor)
                        .lineLimit(1)
                    if case .failed(let message) = job.state {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }
                }

                Spacer(minLength: 8)

                JobActionsView(job: job)

                if canShowSongs {
                    Button {
                        withAnimation { job.showSongs.toggle() }
                    } label: {
                        Image(systemName: job.showSongs ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help(job.showSongs ? "Hide songs" : "Show songs")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)

            if canShowSongs && job.showSongs {
                SongListView(job: job)
                    .padding(.leading, 58)
                    .padding(.trailing, 16)
                    .padding(.bottom, 6)
            }
        }
        .fixMatchSheet(for: job)
    }
}
