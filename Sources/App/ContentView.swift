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

/// The main window. It owns the input, drop and sheet state and shows the chosen layout below the banners.
struct ContentView: View {
    /// Forces a layout. nil uses the saved layout.
    var layoutOverride: AppLayout? = nil

    @EnvironmentObject var dl: Downloader
    @ObservedObject private var settings = SettingsStore.shared
    @StateObject private var ui = InputModel()
    @FocusState private var inputFocused: Bool

    private var input: String {
        get { ui.input }
        nonmutating set { ui.input = newValue }
    }

    private var layout: AppLayout { layoutOverride ?? settings.layout }

    private var ctx: LayoutContext {
        LayoutContext(
            ui: ui,
            focus: $inputFocused,
            submit: submit,
            paste: pasteFromClipboard,
            showSyncList: { ui.showSyncList = true }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if dl.spotdlPath == nil { missingBanner }
            StatusBanners()
            layoutView
        }
        .frame(minWidth: layout == .sidebar ? 780 : 640, minHeight: 480)
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

    @ViewBuilder private var layoutView: some View {
        switch layout {
        case .sidebar: SidebarLayout(ctx: ctx)
        case .nowDownloading: NowDownloadingLayout(ctx: ctx)
        case .classic: ClassicLayout(ctx: ctx)
        }
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
}
