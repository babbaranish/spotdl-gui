import Foundation

/// Checks GitHub for a newer app release at most once a day. StatusBanners shows the result.
@MainActor
final class AppUpdateChecker: ObservableObject {
    static let shared = AppUpdateChecker()

    @Published private(set) var available: AppRelease?

    private let defaults = UserDefaults.standard
    private var checking = false

    private init() {}

    /// Does nothing when the setting is off, a check ran in the last 24 hours, or one is already running.
    func checkIfDue() {
        guard SettingsStore.shared.checkForAppUpdates, !checking else { return }
        let lastCheck = defaults.object(forKey: "lastUpdateCheck") as? Date
        guard VersionCheck.shouldCheck(lastCheck: lastCheck, now: Date()) else { return }

        checking = true
        var request = URLRequest(url: VersionCheck.latestReleaseAPI)
        request.setValue("spotdl-gui", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        Task {
            defer { checking = false }
            // No answer (offline, GitHub down) leaves the date alone, so the next launch tries again.
            guard let result = try? await URLSession.shared.data(for: request),
                  (result.1 as? HTTPURLResponse)?.statusCode == 200
            else { return }
            defaults.set(Date(), forKey: "lastUpdateCheck")
            guard let release = VersionCheck.parseLatestRelease(result.0) else { return }

            let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
            let dismissed = defaults.string(forKey: "dismissedUpdateVersion")
            let isNew = VersionCheck.isNewer(release.version, than: current)
            available = isNew && release.version != dismissed ? release : nil
        }
    }

    /// Hides the current release notice and keeps it hidden for this version only.
    func dismiss() {
        guard let version = available?.version else { return }
        defaults.set(version, forKey: "dismissedUpdateVersion")
        available = nil
    }
}
