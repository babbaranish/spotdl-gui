import AppKit
import SwiftUI

/// Notices under the header: ffmpeg missing, and a newer app release. Shows nothing when all is fine.
struct StatusBanners: View {
    @ObservedObject private var tools = ToolStatus.shared
    @ObservedObject private var updates = AppUpdateChecker.shared

    var body: some View {
        VStack(spacing: 0) {
            if !tools.ffmpegFound {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text("ffmpeg is missing. In Terminal run: brew install ffmpeg")
                        .textSelection(.enabled)
                    Spacer()
                }
                .banner(tint: .orange)
            }
            if let release = updates.available {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill").foregroundStyle(Color.accentColor)
                    Text("spotdl-gui \(release.version) is available.")
                    Spacer()
                    Button("Download") { NSWorkspace.shared.open(release.url) }
                    Button("Dismiss") { updates.dismiss() }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                }
                .banner(tint: .accentColor)
            }
        }
    }
}

private extension View {
    func banner(tint: Color) -> some View {
        self
            .font(.callout)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(tint.opacity(0.15))
    }
}
