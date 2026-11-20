import AppKit
import SwiftUI

/// The Settings window (Cmd+,).
struct SettingsView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @ObservedObject private var tools = ToolStatus.shared
    @EnvironmentObject var dl: Downloader

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Layout", selection: $settings.layout) {
                    ForEach(AppLayout.allCases) { Text($0.label).tag($0) }
                }
                Text(settings.layout.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Downloads") {
                Picker("Format", selection: $settings.options.format) {
                    ForEach(AudioFormat.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(settings.options.format.help)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Synced lyrics (.lrc files)", isOn: $settings.options.syncedLyrics)

                Picker("Audio source", selection: $settings.options.audioSource) {
                    ForEach(AudioSource.allCases) { Text($0.label).tag($0) }
                }

                cookiesRow

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        TextField("File name", text: $settings.options.fileNameTemplate)
                            .textFieldStyle(.roundedBorder)
                        Button("Reset") { settings.options.fileNameTemplate = DownloadOptions.defaultFileNameTemplate }
                            .disabled(settings.options.fileNameTemplate == DownloadOptions.defaultFileNameTemplate)
                    }
                    if DownloadOptions.isValidTemplate(settings.options.fileNameTemplate) {
                        Text("Lists go into their own folder. Must contain {title} and end with .{output-ext}. {artists} is optional.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Must contain {title}, end with .{output-ext} and have no \"/\". Using the default name until fixed.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            Section("After downloading") {
                Toggle("Notify me when downloads finish", isOn: $settings.notifyWhenDone)
                    .onChange(of: settings.notifyWhenDone) { _, on in
                        if on { Notifier.requestAuthorizationIfNeeded() }
                    }
                Toggle("Add finished songs to Music", isOn: $settings.addToMusicAutomatically)
                Text("Opens the new files in Music after each download.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Playlists") {
                Toggle("Sync saved playlists when the app opens", isOn: $settings.syncOnLaunch)
            }

            Section("Updates") {
                Toggle("Check for app updates", isOn: $settings.checkForAppUpdates)
            }

            Section("spotDL") {
                LabeledContent("Version", value: tools.spotdlVersion ?? "Not found")
                LabeledContent("ffmpeg", value: tools.ffmpegFound ? "Found" : "Missing: brew install ffmpeg")
                HStack(spacing: 8) {
                    Button("Update spotDL") { tools.updateSpotDL(spotdlPath: dl.spotdlPath) }
                        .disabled(tools.isUpdating || dl.spotdlPath == nil)
                    if tools.isUpdating {
                        ProgressView().controlSize(.small)
                    }
                    Spacer()
                    if let message = tools.updateMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .onAppear { tools.refresh(spotdlPath: dl.spotdlPath) }
    }

    private var cookiesRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("Cookies file")
                Spacer()
                Text(cookieName)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button("Choose…", action: chooseCookieFile)
                    .buttonStyle(.borderless)
                if settings.options.cookieFile != nil {
                    Button("Clear") { settings.options.cookieFile = nil }
                        .buttonStyle(.borderless)
                }
            }
            Text("Lets YouTube Music Premium accounts download 256 kbps audio.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var cookieName: String {
        guard let path = settings.options.cookieFile,
              !path.trimmingCharacters(in: .whitespaces).isEmpty
        else { return "None" }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    private func chooseCookieFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url { settings.options.cookieFile = url.path }
    }
}
