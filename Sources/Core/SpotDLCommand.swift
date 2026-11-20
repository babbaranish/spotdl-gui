import Foundation

/// How the app invokes the spotdl command line tool.
enum SpotDLCommand {
    /// Lists get their own folder; single songs go straight into the output folder.
    static func outputTemplate(for kind: JobKind) -> String {
        (kind.usesFolder ? "{list-name}/" : "") + "{artists} - {title}.{output-ext}"
    }

    static func arguments(query: String, kind: JobKind, format: AudioFormat) -> [String] {
        ["download", query] + format.args + ["--output", outputTemplate(for: kind), "--simple-tui"]
    }

    /// Apps launched from Finder get a minimal PATH, and spotDL needs ffmpeg on it.
    /// The other variables keep spotDL's output plain, unbuffered and on one line per event.
    static func environment(base: [String: String], home: String) -> [String: String] {
        var env = base
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:\(home)/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        env["COLUMNS"] = "1000"
        env["PYTHONUNBUFFERED"] = "1"
        env["NO_COLOR"] = "1"
        env["TERM"] = "dumb"
        return env
    }

    static func candidatePaths(home: String) -> [String] {
        ["\(home)/.local/bin/spotdl", "/opt/homebrew/bin/spotdl", "/usr/local/bin/spotdl"]
    }

    /// Mirrors spotDL's sanitize_string so we can find the playlist folder.
    static func sanitize(_ s: String) -> String {
        var out = String(s.filter { !"/?\\*|<>".contains($0) })
        out = out.replacing(/\s{2,}/, with: " ")
        return out.replacingOccurrences(of: "\"", with: "'").replacingOccurrences(of: ":", with: "-")
    }
}
