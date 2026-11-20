import Foundation

/// How the main window is arranged. Picked in Settings and in the View menu.
enum AppLayout: String, CaseIterable, Identifiable, Codable {
    case sidebar, nowDownloading, classic

    static let defaultLayout: AppLayout = .sidebar

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sidebar: return "Sidebar"
        case .nowDownloading: return "Now downloading"
        case .classic: return "Classic"
        }
    }

    var summary: String {
        switch self {
        case .sidebar: return "A sidebar for the queue, finished jobs and synced playlists."
        case .nowDownloading: return "A big card for the current download, with the rest listed below."
        case .classic: return "The original single list of job cards."
        }
    }

    /// The saved raw value, or the default when nothing (or something unknown) is saved.
    init(stored: String?) {
        self = stored.flatMap(AppLayout.init(rawValue:)) ?? .defaultLayout
    }
}

/// The job groups in the sidebar layout.
enum JobFilter: String, CaseIterable, Identifiable {
    case queue, finished, attention

    var id: String { rawValue }

    var label: String {
        switch self {
        case .queue: return "Queue"
        case .finished: return "Finished"
        case .attention: return "Needs attention"
        }
    }

    var symbol: String {
        switch self {
        case .queue: return "arrow.down.circle"
        case .finished: return "checkmark.circle"
        case .attention: return "exclamationmark.triangle"
        }
    }

    /// Queue: waiting or running. Needs attention: failed, or done with failed songs. Finished: the rest.
    func matches(state: JobState, failedCount: Int) -> Bool {
        switch self {
        case .queue:
            return state.isActive
        case .attention:
            if case .failed = state { return true }
            return state == .done && failedCount > 0
        case .finished:
            return (state == .done && failedCount == 0) || state == .cancelled
        }
    }
}
