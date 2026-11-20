import SwiftUI

/// Holds the link being typed and the error under it (the Command Line Tools SDK lacks the @State macro plugin).
@MainActor
final class SyncListModel: ObservableObject {
    @Published var link = ""
    @Published var error: String?
}

/// Sheet listing the synced playlists, albums and artists.
struct SyncListView: View {
    let currentOutputDir: URL
    let onSync: (SyncedPlaylist) -> Void
    let onSyncAll: () -> Void
    let onClose: () -> Void

    @ObservedObject private var store = SyncStore.shared
    @StateObject private var ui = SyncListModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Synced playlists")
                .font(.title3.weight(.semibold))
            addRow
            if let error = ui.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if store.playlists.isEmpty {
                emptyState
            } else {
                List(store.playlists) { playlist in
                    row(playlist)
                }
            }
            Divider()
            HStack(spacing: 8) {
                Spacer()
                Button("Sync All", action: onSyncAll)
                    .disabled(store.playlists.isEmpty)
                Button("Done", action: onClose)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 540, height: 460)
    }

    private var addRow: some View {
        HStack(spacing: 8) {
            TextField("Paste a playlist, album or artist link", text: $ui.link)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addLink)
            Button("Add", action: addLink)
                .disabled(ui.link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func row(_ playlist: SyncedPlaylist) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(playlist.title)
                .font(.headline)
                .lineLimit(1)
            Text(playlist.url)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(lastSyncedText(playlist))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Toggle("Remove songs taken off the playlist", isOn: deleteRemovedBinding(playlist))
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Spacer()
                Button("Sync") { onSync(playlist) }
                    .controlSize(.small)
                Button("Remove", role: .destructive) { store.remove(playlist.id) }
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No synced playlists yet")
                .font(.headline)
            Text("Paste a Spotify playlist, album or artist link above. Press Sync to download the songs added since the last sync.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func lastSyncedText(_ playlist: SyncedPlaylist) -> String {
        guard let date = playlist.lastSynced else { return "Never synced" }
        return "Last synced " + date.formatted(.relative(presentation: .named))
    }

    private func deleteRemovedBinding(_ playlist: SyncedPlaylist) -> Binding<Bool> {
        Binding(
            get: { playlist.deleteRemoved },
            set: { value in
                guard var current = store.playlists.first(where: { $0.id == playlist.id }) else { return }
                current.deleteRemoved = value
                store.update(current)
            }
        )
    }

    private func addLink() {
        let link = ui.link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !link.isEmpty else { return }
        guard SyncedPlaylist.canSync(link) else {
            ui.error = "Only Spotify playlist, album and artist links can be kept in sync."
            return
        }
        guard !store.contains(url: link) else {
            ui.error = "That link is already in your list."
            return
        }
        // The real name comes from spotDL on the first sync.
        guard store.add(url: link, title: JobKind(query: link).placeholderTitle, outputDir: currentOutputDir,
                        options: SettingsStore.shared.options) != nil
        else {
            ui.error = "Could not add that link."
            return
        }
        ui.link = ""
        ui.error = nil
    }
}
