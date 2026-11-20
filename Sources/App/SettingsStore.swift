import Foundation

/// App settings. The download options are stored as JSON; the toggles are plain booleans in UserDefaults.
@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var options: DownloadOptions {
        didSet {
            if let data = try? JSONEncoder().encode(options) {
                defaults.set(data, forKey: "downloadOptions")
            }
        }
    }
    @Published var notifyWhenDone: Bool {
        didSet { defaults.set(notifyWhenDone, forKey: "notifyWhenDone") }
    }
    @Published var addToMusicAutomatically: Bool {
        didSet { defaults.set(addToMusicAutomatically, forKey: "addToMusicAutomatically") }
    }
    @Published var checkForAppUpdates: Bool {
        didSet { defaults.set(checkForAppUpdates, forKey: "checkForAppUpdates") }
    }
    @Published var syncOnLaunch: Bool {
        didSet { defaults.set(syncOnLaunch, forKey: "syncOnLaunch") }
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        options = Self.loadOptions(defaults)
        notifyWhenDone = defaults.object(forKey: "notifyWhenDone") as? Bool ?? true
        addToMusicAutomatically = defaults.object(forKey: "addToMusicAutomatically") as? Bool ?? false
        checkForAppUpdates = defaults.object(forKey: "checkForAppUpdates") as? Bool ?? true
        syncOnLaunch = defaults.object(forKey: "syncOnLaunch") as? Bool ?? false
    }

    /// Stored options, or the defaults with the old "format" key applied when nothing (or bad JSON) is stored.
    private static func loadOptions(_ defaults: UserDefaults) -> DownloadOptions {
        let legacyFormat = AudioFormat(rawValue: defaults.string(forKey: "format") ?? "") ?? .mp3
        guard let data = defaults.data(forKey: "downloadOptions"),
              let stored = try? JSONDecoder().decode(DownloadOptions.self, from: data)
        else { return DownloadOptions(format: legacyFormat) }
        return stored
    }
}
