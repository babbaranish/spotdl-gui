import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Holds text-field, drop and sheet state (the Command Line Tools SDK lacks the @State macro plugin).
@MainActor
final class InputModel: ObservableObject {
    @Published var input = ""
    @Published var dropTargeted = false
    @Published var showSyncList = false
    var lastPrefill = ""
}

struct ContentView: View {
    @EnvironmentObject var dl: Downloader
    @ObservedObject private var settings = SettingsStore.shared
    @StateObject private var ui = InputModel()
    @FocusState private var inputFocused: Bool

    private var input: String {
        get { ui.input }
        nonmutating set { ui.input = newValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            if dl.spotdlPath == nil { missingBanner }
            StatusBanners()
            header
            Divider()
            if dl.jobs.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(dl.jobs) { JobRow(job: $0) }
                    }
                    .padding(16)
                }
            }
            Divider()
            footer
        }
        .frame(minWidth: 640, minHeight: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay {
            if ui.dropTargeted {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.08)))
                    .padding(4)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.url, .plainText], isTargeted: $ui.dropTargeted, perform: handleDrop)
        .sheet(isPresented: $ui.showSyncList) {
            SyncListView(
                currentOutputDir: dl.outputDir,
                onSync: { playlist in
                    dl.sync(playlist)
                    ui.showSyncList = false
                },
                onSyncAll: {
                    dl.syncAll()
                    ui.showSyncList = false
                },
                onClose: { ui.showSyncList = false }
            )
        }
        .onAppear {
            inputFocused = true
            prefillFromClipboard()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            prefillFromClipboard()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .foregroundStyle(.secondary)
                    TextField("Paste a Spotify link, or type a song name", text: $ui.input)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .focused($inputFocused)
                        .onSubmit(submit)
                    if input.isEmpty {
                        Button("Paste") { pasteFromClipboard() }
                            .buttonStyle(.borderless)
                            .help("Paste from clipboard")
                    } else {
                        Button { input = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.borderless)
                        .help("Clear")
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color(nsColor: .textBackgroundColor)))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(inputFocused ? Color.accentColor.opacity(0.7) : Color(nsColor: .separatorColor), lineWidth: inputFocused ? 2 : 1)
                )

                Picker("Format", selection: $settings.options.format) {
                    ForEach(AudioFormat.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 160)
                .help(settings.options.format.help)

                Button(action: submit) {
                    Label("Download", systemImage: "arrow.down.circle.fill")
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || dl.spotdlPath == nil)
            }
            Text(settings.options.format.help)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
        .padding(16)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note.list")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Paste a Spotify link to start")
                .font(.title3.weight(.semibold))
            Text("Songs, albums, playlists and artists all work. Add more links while others download; they wait in line.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var footer: some View {
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
            Spacer()
            Button("Synced playlists") { ui.showSyncList = true }
                .buttonStyle(.borderless)
                .help("Playlists, albums and artists kept up to date")
            if dl.hasFinished {
                Button("Clear finished") { withAnimation { dl.clearFinished() } }
                    .buttonStyle(.borderless)
            }
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .frame(height: 38)
    }

    private var missingBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("spotDL is not installed. In Terminal run: uv tool install spotdl --python 3.12")
                .textSelection(.enabled)
            Spacer()
        }
        .font(.callout)
        .foregroundStyle(.white)
        .padding(10)
        .background(Color.red.opacity(0.85))
    }

    private func submit() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, dl.spotdlPath != nil else { return }
        withAnimation(.snappy) { dl.add(text) }
        ui.lastPrefill = text
        input = ""
        inputFocused = true
    }

    /// Links dropped from a browser arrive as URLs; text dragged from elsewhere arrives as a string.
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard dl.spotdlPath != nil else { return false }
        let downloader = dl
        var accepted = false
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                accepted = true
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url, url.scheme == "http" || url.scheme == "https" else { return }
                    let link = url.absoluteString
                    Task { @MainActor in downloader.add(link) }
                }
            } else if provider.canLoadObject(ofClass: String.self) {
                accepted = true
                _ = provider.loadObject(ofClass: String.self) { text, _ in
                    guard let text else { return }
                    Task { @MainActor in downloader.add(text) }
                }
            }
        }
        return accepted
    }

    private func pasteFromClipboard() {
        if let s = NSPasteboard.general.string(forType: .string) {
            input = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// When you come back from Spotify with a link copied, it is already filled in.
    private func prefillFromClipboard() {
        guard ProcessInfo.processInfo.environment["SPOTDL_GUI_AUTOADD"] == nil else { return }
        guard input.isEmpty,
              let s = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              QueryInput.isSpotifyLink(s),
              s != ui.lastPrefill,
              !dl.jobs.contains(where: { $0.query == s })
        else { return }
        input = s
        ui.lastPrefill = s
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
