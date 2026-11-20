import SwiftUI

struct SongLine: View {
    let song: SongRow

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
