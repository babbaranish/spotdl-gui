import SwiftUI

/// The original layout: one header, one list of job cards and one footer.
struct ClassicLayout: View {
    let ctx: LayoutContext
    @EnvironmentObject var dl: Downloader
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if dl.jobs.isEmpty {
                EmptyJobsView()
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                QueryField(ctx: ctx)
                FormatPicker(style: .segmented)
                    .frame(width: 160)
                DownloadButton(ctx: ctx)
            }
            Text(settings.options.format.help)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
        .padding(16)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            SavingToView()
            Spacer()
            Button("Synced playlists", action: ctx.showSyncList)
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
}
