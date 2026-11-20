import Foundation
import Testing

struct VersionCheckTests {
    private func json(_ s: String) -> Data { Data(s.utf8) }
    private let htmlURL = "https://github.com/babbaranish/spotdl-gui/releases/tag/v1.1.0"

    @Test func latestReleaseAPIPointsAtTheRepo() {
        #expect(VersionCheck.latestReleaseAPI.absoluteString
            == "https://api.github.com/repos/babbaranish/spotdl-gui/releases/latest")
    }

    @Test func parsesTheLatestRelease() {
        let data = json(#"{"tag_name":"v1.1.0","html_url":"\#(htmlURL)","draft":false,"prerelease":false,"name":"1.1.0"}"#)
        #expect(VersionCheck.parseLatestRelease(data) == AppRelease(version: "1.1.0", url: URL(string: htmlURL)!))
    }

    @Test func tagWithoutVPrefixIsKept() {
        let data = json(#"{"tag_name":"1.2","html_url":"\#(htmlURL)"}"#)
        #expect(VersionCheck.parseLatestRelease(data)?.version == "1.2")
    }

    @Test func draftsAndPrereleasesAreIgnored() {
        #expect(VersionCheck.parseLatestRelease(json(#"{"tag_name":"v2.0","html_url":"\#(htmlURL)","draft":true}"#)) == nil)
        #expect(VersionCheck.parseLatestRelease(json(#"{"tag_name":"v2.0","html_url":"\#(htmlURL)","prerelease":true}"#)) == nil)
    }

    @Test func missingFlagsCountAsAFinalRelease() {
        #expect(VersionCheck.parseLatestRelease(json(#"{"tag_name":"v2.0","html_url":"\#(htmlURL)"}"#)) != nil)
    }

    @Test(arguments: [
        "not json",
        "[]",
        "{}",
        #"{"tag_name":"v2.0"}"#,
        #"{"html_url":"https://github.com/x"}"#,
    ])
    func badJSONGivesNil(body: String) {
        #expect(VersionCheck.parseLatestRelease(json(body)) == nil)
    }

    @Test(arguments: [
        ("1.1.0", "1.0.9", true),
        ("1.10.0", "1.9.0", true),
        ("1.0.1", "1.0", true),
        ("v2.0.0", "1.9.9", true),
        ("1.1", "1.1.0", false),
        ("1.1.0", "1.1", false),
        ("1.0.0", "v1.0.0", false),
        ("1.0", "1.0.0.0", false),
        ("1.0.0", "1.0.0", false),
        ("1.0.0-beta", "1.0.0", false),
        ("1.0.0", "1.0.0-beta", false),
        ("", "1.0.0", false),
        ("1.0.0", "x", false),
    ])
    func comparesDottedVersions(candidate: String, current: String, expected: Bool) {
        #expect(VersionCheck.isNewer(candidate, than: current) == expected)
    }

    @Test func checksWhenNeverChecked() {
        #expect(VersionCheck.shouldCheck(lastCheck: nil, now: Date(timeIntervalSince1970: 1_700_000_000)))
    }

    @Test func waitsADayBetweenChecks() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(!VersionCheck.shouldCheck(lastCheck: now.addingTimeInterval(-3600), now: now))
        #expect(!VersionCheck.shouldCheck(lastCheck: now.addingTimeInterval(-86_399), now: now))
        #expect(VersionCheck.shouldCheck(lastCheck: now.addingTimeInterval(-86_400), now: now))
        #expect(VersionCheck.shouldCheck(lastCheck: now.addingTimeInterval(-90_000), now: now))
    }
}
