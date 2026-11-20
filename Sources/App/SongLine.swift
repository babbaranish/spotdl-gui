import SwiftUI

struct SongLine: View {
    let song: SongRow
    /// Set for failed songs that can be fixed with a YouTube link.
    var onFix: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            icon.frame(width: 16)
            Text(song.name)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if case .working(let status) = song.state {
                Text(status).foregroundStyle(.secondary)
            } else if song.state == .skipped {
                Text("Already downloaded").foregroundStyle(.secondary)
            } else if song.state == .failed {
                if let onFix {
                    Button("Fix", action: onFix)
                        .buttonStyle(.borderless)
                        .help("Download the right version from a YouTube link")
                }
                Text("Failed").foregroundStyle(.red)
            }
        }
        .font(.caption)
    }

    @ViewBuilder private var icon: some View {
        switch song.state {
        case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .skipped: Image(systemName: "checkmark.circle").foregroundStyle(.secondary)
        case .failed: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .working: ProgressView().controlSize(.mini)
        }
    }
}
