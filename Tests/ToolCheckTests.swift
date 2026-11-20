import Testing

struct ToolCheckTests {
    @Test func candidatePathsInSearchOrder() {
        #expect(ToolCheck.toolCandidatePaths("spotdl", home: "/Users/x") == [
            "/Users/x/.local/bin/spotdl", "/opt/homebrew/bin/spotdl", "/usr/local/bin/spotdl",
        ])
        #expect(ToolCheck.toolCandidatePaths("ffmpeg", home: "/Users/x") == [
            "/Users/x/.local/bin/ffmpeg", "/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg",
        ])
    }

    @Test(arguments: [
        ("4.6.0", "4.6.0"),
        ("v4.6.0", "4.6.0"),
        ("4.6.0\n", "4.6.0"),
        ("warning: something\n4.6.0\n", "4.6.0"),
        ("  \n4.6.0  \n\n", "4.6.0"),
        ("1", "1"),
    ])
    func parsesVersionFromTheLastLine(output: String, expected: String) {
        #expect(ToolCheck.parseVersion(output) == expected)
    }

    @Test(arguments: ["", "  \n ", "spotdl 4.6.0", "Traceback (most recent call last):", "4.6.0 beta", "vv1.0", "v"])
    func rejectsOutputThatIsNotAVersion(output: String) {
        #expect(ToolCheck.parseVersion(output) == nil)
    }

    @Test func uvInstallIsRecognised() {
        #expect(ToolCheck.installer(
            resolvedPath: "/Users/x/.local/share/uv/tools/spotdl/bin/spotdl",
            uvPath: "/Users/x/.local/bin/uv", pipxPath: "/opt/homebrew/bin/pipx", brewPath: "/opt/homebrew/bin/brew"
        ) == .uv("/Users/x/.local/bin/uv"))
    }

    @Test func pipxInstallIsRecognised() {
        #expect(ToolCheck.installer(
            resolvedPath: "/Users/x/.local/pipx/venvs/spotdl/bin/spotdl",
            uvPath: nil, pipxPath: "/opt/homebrew/bin/pipx", brewPath: "/opt/homebrew/bin/brew"
        ) == .pipx("/opt/homebrew/bin/pipx"))
    }

    @Test func brewInstallIsRecognised() {
        #expect(ToolCheck.installer(
            resolvedPath: "/opt/homebrew/Cellar/spotdl/4.6.0/bin/spotdl",
            uvPath: nil, pipxPath: nil, brewPath: "/opt/homebrew/bin/brew"
        ) == .brew("/opt/homebrew/bin/brew"))
    }

    @Test func installerNeedsItsToolToBeFound() {
        #expect(ToolCheck.installer(
            resolvedPath: "/Users/x/.local/share/uv/tools/spotdl/bin/spotdl",
            uvPath: nil, pipxPath: nil, brewPath: nil
        ) == .unknown)
        #expect(ToolCheck.installer(
            resolvedPath: "/Users/x/.local/share/uv/tools/spotdl/bin/spotdl",
            uvPath: "", pipxPath: nil, brewPath: nil
        ) == .unknown)
    }

    @Test func unknownLocationIsUnknown() {
        #expect(ToolCheck.installer(
            resolvedPath: "/usr/local/bin/spotdl",
            uvPath: "/u/uv", pipxPath: "/p/pipx", brewPath: "/b/brew"
        ) == .unknown)
    }

    @Test func upgradeCommandPerInstaller() {
        let uv = ToolCheck.upgradeCommand(.uv("/u/uv"))
        #expect(uv?.executable == "/u/uv")
        #expect(uv?.arguments == ["tool", "upgrade", "spotdl"])

        let pipx = ToolCheck.upgradeCommand(.pipx("/p/pipx"))
        #expect(pipx?.executable == "/p/pipx")
        #expect(pipx?.arguments == ["upgrade", "spotdl"])

        let brew = ToolCheck.upgradeCommand(.brew("/b/brew"))
        #expect(brew?.executable == "/b/brew")
        #expect(brew?.arguments == ["upgrade", "spotdl"])

        #expect(ToolCheck.upgradeCommand(.unknown) == nil)
    }
}
