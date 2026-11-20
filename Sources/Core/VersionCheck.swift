import Foundation

struct AppRelease: Equatable { let version: String; let url: URL }

/// Checks GitHub for a newer release of the app. Nothing here touches the network.
enum VersionCheck {
    static let latestReleaseAPI = URL(string: "https://api.github.com/repos/babbaranish/spotdl-gui/releases/latest")!

    private struct Release: Decodable {
        let tag_name: String
        let html_url: String
        let draft: Bool?
        let prerelease: Bool?
    }

    /// tag_name (leading "v" stripped) + html_url; nil on bad JSON or when draft/prerelease is true.
    static func parseLatestRelease(_ data: Data) -> AppRelease? {
        guard let release = try? JSONDecoder().decode(Release.self, from: data),
              release.draft != true, release.prerelease != true,
              let url = URL(string: release.html_url)
        else { return nil }
        let version = release.tag_name.hasPrefix("v") ? String(release.tag_name.dropFirst()) : release.tag_name
        return AppRelease(version: version, url: url)
    }

    /// Dotted numeric compare, missing parts are 0, leading "v" ignored, any non-numeric part -> false.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        guard let a = numericParts(candidate), let b = numericParts(current) else { return false }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    /// true when lastCheck is nil or at least 24 hours before now.
    static func shouldCheck(lastCheck: Date?, now: Date) -> Bool {
        guard let lastCheck else { return true }
        return now.timeIntervalSince(lastCheck) >= 24 * 60 * 60
    }

    private static func numericParts(_ version: String) -> [Int]? {
        let v = version.hasPrefix("v") ? String(version.dropFirst()) : version
        var parts: [Int] = []
        for part in v.split(separator: ".", omittingEmptySubsequences: false) {
            guard !part.isEmpty, part.allSatisfy({ $0 >= "0" && $0 <= "9" }), let n = Int(part) else { return nil }
            parts.append(n)
        }
        return parts
    }
}
