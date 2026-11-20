import Foundation

/// Finds spotDL and its helpers, and works out how spotDL was installed so it can be upgraded.
enum ToolCheck {
    enum Installer: Equatable { case uv(String), pipx(String), brew(String), unknown }   // payload: tool executable path

    static func toolCandidatePaths(_ name: String, home: String) -> [String] {
        ["\(home)/.local/bin/\(name)", "/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)"]
    }

    /// Last non-empty line if it looks like a version (digits and dots, optional leading "v" stripped), else nil.
    static func parseVersion(_ output: String) -> String? {
        guard let last = output.split(whereSeparator: \.isNewline)
            .map({ $0.trimmingCharacters(in: .whitespaces) })
            .last(where: { !$0.isEmpty })
        else { return nil }
        let version = last.hasPrefix("v") ? String(last.dropFirst()) : last
        guard version.wholeMatch(of: #/[0-9]+(\.[0-9]+)*/#) != nil else { return nil }
        return version
    }

    static func installer(resolvedPath: String, uvPath: String?, pipxPath: String?, brewPath: String?) -> Installer {
        if resolvedPath.contains("/uv/tools/spotdl/"), let uv = uvPath, !uv.isEmpty { return .uv(uv) }
        if resolvedPath.contains("/pipx/venvs/spotdl/"), let pipx = pipxPath, !pipx.isEmpty { return .pipx(pipx) }
        if resolvedPath.contains("/Cellar/spotdl/"), let brew = brewPath, !brew.isEmpty { return .brew(brew) }
        return .unknown
    }

    static func upgradeCommand(_ installer: Installer) -> (executable: String, arguments: [String])? {
        switch installer {
        case .uv(let path): return (path, ["tool", "upgrade", "spotdl"])
        case .pipx(let path): return (path, ["upgrade", "spotdl"])
        case .brew(let path): return (path, ["upgrade", "spotdl"])
        case .unknown: return nil
        }
    }
}
