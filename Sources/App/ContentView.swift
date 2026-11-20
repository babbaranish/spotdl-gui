import AppKit
import SwiftUI

/// Holds text-field state (the Command Line Tools SDK lacks the @State macro plugin).
@MainActor
final class InputModel: ObservableObject {
    @Published var input = ""
    var lastPrefill = ""
}

struct ContentView: View {
    @EnvironmentObject var dl: Downloader
    @StateObject private var ui = InputModel()
    @FocusState private var inputFocused: Bool

    private var input: String {
        get { ui.input }
        nonmutating set { ui.input = newValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            if dl.spotdlPath == nil { missingBanner }
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

                Picker("Format", selection: $dl.format) {
                    ForEach(AudioFormat.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 160)
                .help(dl.format.help)

                Button(action: submit) {
                    Label("Download", systemImage: "arrow.down.circle.fill")
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || dl.spotdlPath == nil)
            }
            Text(dl.format.help)
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
