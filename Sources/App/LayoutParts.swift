import AppKit
import SwiftUI

/// What a layout needs from the host window. The host owns the input text, focus and actions.
struct LayoutContext {
    let ui: InputModel
    let focus: FocusState<Bool>.Binding
    let submit: () -> Void
    let paste: () -> Void
    let showSyncList: () -> Void
}

/// The Spotify link box: paste button, clear button and focus ring.
struct QueryField: View {
    let ctx: LayoutContext
    let large: Bool
    @ObservedObject private var ui: InputModel
    /// Held as a property wrapper so the focus ring redraws when focus changes.
    @FocusState.Binding private var focused: Bool

    init(ctx: LayoutContext, large: Bool = false) {
        self.ctx = ctx
        self.large = large
        _ui = ObservedObject(wrappedValue: ctx.ui)
        _focused = ctx.focus
    }
    private var height: CGFloat { large ? 48 : 38 }
    private var radius: CGFloat { large ? 14 : 9 }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .foregroundStyle(.secondary)
            TextField("Paste a Spotify link, or type a song name", text: $ui.input)
                .textFieldStyle(.plain)
                .font(.system(size: large ? 17 : 15))
                .focused($focused)
                .onSubmit(ctx.submit)
            if ui.input.isEmpty {
                Button("Paste", action: ctx.paste)
                    .buttonStyle(.borderless)
                    .help("Paste from clipboard")
            } else {
                Button { ui.input = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.borderless)
                .help("Clear")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: height)
        .background(RoundedRectangle(cornerRadius: radius).fill(Color(nsColor: .textBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(focused ? Color.accentColor.opacity(0.7) : Color(nsColor: .separatorColor), lineWidth: focused ? 2 : 1)
        )
    }
}

/// The audio format choice, bound to the saved download options.
struct FormatPicker: View {
    enum Style { case segmented, menu, pills }

    let style: Style
    @ObservedObject private var settings = SettingsStore.shared

    init(style: Style) {
        self.style = style
    }

    var body: some View {
        switch style {
        case .segmented:
            picker.pickerStyle(.segmented).labelsHidden().help(settings.options.format.help)
        case .menu:
            picker.pickerStyle(.menu).labelsHidden().help(settings.options.format.help)
        case .pills:
            HStack(spacing: 6) {
                ForEach(AudioFormat.allCases) { format in
                    let selected = format == settings.options.format
                    Button { settings.options.format = format } label: {
                        Text(format.label)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(selected ? Color.black : Color.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(selected ? Color.accentColor : Color.secondary.opacity(0.15)))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .help(format.help)
                }
            }
        }
    }

    private var picker: some View {
        Picker("Format", selection: $settings.options.format) {
            ForEach(AudioFormat.allCases) { Text($0.label).tag($0) }
        }
    }
}

/// The Download button. Disabled while the box is blank or spotDL is missing.
struct DownloadButton: View {
    let ctx: LayoutContext
    let large: Bool
    @ObservedObject private var ui: InputModel
    @EnvironmentObject var dl: Downloader

    init(ctx: LayoutContext, large: Bool = true) {
        self.ctx = ctx
        self.large = large
        _ui = ObservedObject(wrappedValue: ctx.ui)
    }

    var body: some View {
        Button(action: ctx.submit) {
            Label("Download", systemImage: "arrow.down.circle.fill")
                .padding(.horizontal, 4)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(large ? .large : .regular)
        .keyboardShortcut(.defaultAction)
        .disabled(ui.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || dl.spotdlPath == nil)
    }
}

/// Cover art for a job, or its kind symbol on a tinted square until the art loads.
struct ArtworkView: View {
    @ObservedObject var job: Job
    let size: CGFloat
    let cornerRadius: CGFloat

    init(job: Job, size: CGFloat, cornerRadius: CGFloat) {
        _job = ObservedObject(wrappedValue: job)
        self.size = size
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius).fill(job.tint.opacity(0.15))
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
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var kindSymbol: some View {
        Image(systemName: job.kind.symbol)
            .font(.system(size: max(13, size * 0.36)))
            .foregroundStyle(job.tint)
    }
}

/// The buttons on a job: Cancel, Retry, Show in Finder, the more menu and remove.
struct JobActionsView: View {
    @ObservedObject var job: Job
    @EnvironmentObject var dl: Downloader
    @ObservedObject private var syncStore = SyncStore.shared

    init(job: Job) {
        _job = ObservedObject(wrappedValue: job)
    }

    /// Album, playlist and artist downloads that are not synced yet.
    private var canKeepInSync: Bool {
        job.syncedPlaylist == nil && SyncedPlaylist.canSync(job.query) && !syncStore.contains(url: job.query)
    }

    var body: some View {
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
}

/// The songs of a job, each with its state. Failed songs get a Fix button once the job has finished.
struct SongListView: View {
    @ObservedObject var job: Job
    let maxHeight: CGFloat

    init(job: Job, maxHeight: CGFloat = 220) {
        _job = ObservedObject(wrappedValue: job)
        self.maxHeight = maxHeight
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(job.songs) { song in
                    SongLine(song: song, onFix: fixAction(for: song))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .frame(maxHeight: maxHeight)
    }

    private func fixAction(for song: SongRow) -> (() -> Void)? {
        guard song.state == .failed, job.isFinished else { return nil }
        return { job.fixingSong = song.name }
    }
}

/// "Saving to ~/Music/spotDL  Change...": opens the folder, or picks a new one.
struct SavingToView: View {
    @EnvironmentObject var dl: Downloader

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder").foregroundStyle(.secondary)
            Text("Saving to").foregroundStyle(.secondary)
            Button {
                try? FileManager.default.createDirectory(at: dl.outputDir, withIntermediateDirectories: true)
                NSWorkspace.shared.open(dl.outputDir)
            } label: {
                Text(displayPath(dl.outputDir)).lineLimit(1).truncationMode(.middle)
            }
            .buttonStyle(.link)
            .help("Open folder")
            Button("Change…", action: chooseFolder)
                .buttonStyle(.borderless)
        }
        .font(.callout)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Save Here"
        panel.directoryURL = dl.outputDir
        if panel.runModal() == .OK, let url = panel.url { dl.outputDir = url }
    }

    private func displayPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return url.path.hasPrefix(home) ? "~" + url.path.dropFirst(home.count) : url.path
    }
}

/// Shown when there are no jobs.
struct EmptyJobsView: View {
    let title: String
    let message: String

    init(title: String = "Paste a Spotify link to start",
         message: String = "Songs, albums, playlists and artists all work. Add more links while others download; they wait in line.") {
        self.title = title
        self.message = message
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note.list")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

extension View {
    /// Opens the Fix sheet for the job's failed song (set by SongListView).
    func fixMatchSheet(for job: Job) -> some View {
        modifier(FixMatchModifier(job: job))
    }
}

private struct FixMatchModifier: ViewModifier {
    @ObservedObject var job: Job
    @EnvironmentObject var dl: Downloader

    func body(content: Content) -> some View {
        content.sheet(isPresented: fixSheetShown) {
            FixMatchSheet(
                songName: job.fixingSong ?? "",
                knownSpotifyLink: knownSpotifyLink,
                onSubmit: { query in dl.fixMatch(in: job, query: query) },
                onCancel: { job.fixingSong = nil }
            )
        }
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
}

extension Job {
    var statusLine: String {
        switch state {
        case .waiting:
            return "Waiting in line"
        case .fetching where rateLimited:
            return "Spotify is rate limiting. Still trying, or cancel and retry later."
        case .fetching:
            return kind.usesFolder ? "Finding songs… (big playlists take a minute)" : "Finding song…"
        case .downloading:
            if let total, total > 1 {
                return "Downloading \(finishedCount) of \(total)"
            }
            return "Downloading…"
        case .done:
            let summary = doneSummary
            if summary.isEmpty { return "Done" }
            // Only the single-song results stand alone; the rest read like "Done: 12 saved, 1 failed".
            return summary == "Downloaded" || summary == "Already downloaded" ? summary : "Done: " + summary
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        }
    }

    var statusColor: Color {
        switch state {
        case .failed: return .red
        case .done where failedCount > 0: return .orange
        default: return .secondary
        }
    }

    var tint: Color {
        switch state {
        case .done: return failedCount > 0 ? .orange : .green
        case .failed: return .red
        case .cancelled: return .secondary
        default: return .accentColor
        }
    }
}
