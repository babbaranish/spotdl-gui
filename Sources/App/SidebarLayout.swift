import SwiftUI

/// What the sidebar shows: a job group, or one synced playlist.
enum SidebarItem: Hashable {
    case filter(JobFilter)
    case playlist(UUID)
}

/// Holds the sidebar selection (the Command Line Tools SDK lacks the @State macro plugin).
final class SidebarModel: ObservableObject {
    @Published var selection: SidebarItem? = .filter(.queue)
}

/// A sidebar of job groups and synced playlists, with the link box and the jobs on the right.
struct SidebarLayout: View {
    let ctx: LayoutContext
    @EnvironmentObject var dl: Downloader
    @ObservedObject private var syncStore = SyncStore.shared
    @StateObject private var model = SidebarModel()

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 210)
            Divider()
            detail
        }
        .onChange(of: dl.jobs.count) { old, new in
            // A new download is in the queue, so show the queue. A playlist page keeps showing its own sync.
            if new > old, case .filter(let filter) = model.selection, filter != .queue {
                model.selection = .filter(.queue)
            }
        }
        .onChange(of: syncStore.playlists.map(\.id)) { _, ids in
            // The selected playlist was removed, so fall back to the queue.
            if case .playlist(let id) = model.selection, !ids.contains(id) {
                model.selection = .filter(.queue)
            }
        }
    }

    /// The selection as shown. A playlist that no longer exists shows the queue until onChange resets it.
    private var current: SidebarItem {
        if case .playlist(let id) = model.selection, !syncStore.playlists.contains(where: { $0.id == id }) {
            return .filter(.queue)
        }
        return model.selection ?? .filter(.queue)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $model.selection) {
                Section("Downloads") {
                    ForEach(JobFilter.allCases) { filter in
                        filterRow(filter)
                            .tag(SidebarItem.filter(filter))
                    }
                }
                Section("Synced playlists") {
                    if syncStore.playlists.isEmpty {
                        Text("None yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(syncStore.playlists) { playlist in
                            Label(playlist.title, systemImage: "arrow.triangle.2.circlepath")
                                .lineLimit(1)
                                .tag(SidebarItem.playlist(playlist.id))
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Button("Manage playlists…", action: ctx.showSyncList)
                    .buttonStyle(.borderless)
                SettingsLink { Label("Settings", systemImage: "gearshape") }
                    .buttonStyle(.borderless)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func filterRow(_ filter: JobFilter) -> some View {
        let count = dl.jobs.filter { filter.matches(state: $0.state, failedCount: $0.failedCount) }.count
        return HStack {
            Label {
                Text(filter.label)
            } icon: {
                filterIcon(filter, alert: filter == .attention && count > 0)
            }
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private func filterIcon(_ filter: JobFilter, alert: Bool) -> some View {
        if alert {
            Image(systemName: filter.symbol).foregroundStyle(.orange)
        } else {
            Image(systemName: filter.symbol)
        }
    }

    // MARK: Detail

    private var detail: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                QueryField(ctx: ctx)
                FormatPicker(style: .menu)
                    .fixedSize()
                DownloadButton(ctx: ctx, large: false)
            }
            .padding(12)
            Divider()
            content
            Divider()
            footer
        }
    }

    @ViewBuilder
    private var content: some View {
        switch current {
        case .filter(let filter):
            filterContent(filter)
        case .playlist(let id):
            if let playlist = syncStore.playlists.first(where: { $0.id == id }) {
                playlistContent(playlist)
            } else {
                filterContent(.queue)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            SavingToView()
            Spacer()
            if dl.hasFinished {
                Button("Clear finished") { withAnimation { dl.clearFinished() } }
                    .buttonStyle(.borderless)
            }
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .frame(height: 34)
    }

    @ViewBuilder
    private func filterContent(_ filter: JobFilter) -> some View {
        let jobs = dl.jobs.filter { filter.matches(state: $0.state, failedCount: $0.failedCount) }
        if jobs.isEmpty {
            emptyState(for: filter)
        } else {
            jobList(jobs)
        }
    }

    @ViewBuilder
    private func emptyState(for filter: JobFilter) -> some View {
        switch filter {
        case .queue:
            EmptyJobsView()
        case .finished:
            EmptyJobsView(title: "Nothing finished yet", message: "Finished downloads show up here.")
        case .attention:
            EmptyJobsView(title: "Nothing needs attention",
                          message: "Failed downloads and songs that need a fix show up here.")
        }
    }

    private func jobList(_ jobs: [Job]) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(jobs.enumerated()), id: \.element.id) { index, job in
                    if index > 0 { Divider() }
                    SidebarJobRow(job: job)
                }
            }
        }
    }

    @ViewBuilder
    private func playlistContent(_ playlist: SyncedPlaylist) -> some View {
        let jobs = dl.jobs.filter { $0.syncedPlaylist?.id == playlist.id }
        VStack(spacing: 0) {
            playlistHeader(playlist)
            Divider()
            if jobs.isEmpty {
                EmptyJobsView(title: "No syncs yet", message: "Press Sync now to download new songs.")
            } else {
                jobList(jobs)
            }
        }
    }

    private func playlistHeader(_ playlist: SyncedPlaylist) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(playlist.title)
                .font(.title2.bold())
                .lineLimit(1)
            Text(playlist.url)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .textSelection(.enabled)
            Text(lastSyncedText(playlist))
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button("Sync now") { dl.sync(playlist) }
                    .buttonStyle(.borderedProminent)
                Button("Manage…", action: ctx.showSyncList)
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private func lastSyncedText(_ playlist: SyncedPlaylist) -> String {
        guard let date = playlist.lastSynced else { return "Never synced" }
        return "Last synced " + date.formatted(.relative(presentation: .named))
    }
}

/// One job in the sidebar list: artwork, title and status, progress, actions and the song list.
private struct SidebarJobRow: View {
    @ObservedObject var job: Job

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ArtworkView(job: job, size: 40, cornerRadius: 6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(job.title)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(job.query)
                    Text(job.statusLine)
                        .font(.subheadline)
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

                if job.state == .downloading {
                    VStack(alignment: .trailing, spacing: 4) {
                        if let total = job.total, total > 1 {
                            Text("\(job.finishedCount) of \(total)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let progress = job.progress {
                            ProgressView(value: progress)
                                .frame(width: 140)
                        } else {
                            ProgressView().progressViewStyle(.linear).frame(width: 140)
                        }
                    }
                }

                if job.state == .fetching {
                    ProgressView().controlSize(.small)
                }

                Text(job.format.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))

                JobActionsView(job: job)

                if job.songs.count > 1 || job.failedCount > 0 {
                    Button { withAnimation { job.showSongs.toggle() } } label: {
                        Image(systemName: job.showSongs ? "chevron.down" : "chevron.right")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help(job.showSongs ? "Hide songs" : "Show songs")
                }
            }

            if job.showSongs {
                SongListView(job: job)
                    .padding(.leading, 52)
                    .padding(.top, 8)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .fixMatchSheet(for: job)
    }
}
