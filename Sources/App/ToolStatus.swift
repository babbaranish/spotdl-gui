import Foundation

/// The spotDL install, ffmpeg and the installer that can upgrade spotDL. Checks run off the main thread.
@MainActor
final class ToolStatus: ObservableObject {
    static let shared = ToolStatus()

    @Published private(set) var spotdlVersion: String?
    @Published private(set) var ffmpegFound = true
    @Published private(set) var installer: ToolCheck.Installer = .unknown
    @Published private(set) var isUpdating = false
    @Published private(set) var updateMessage: String?

    private init() {}

    /// Reads the spotDL version and checks ffmpeg and the installer.
    func refresh(spotdlPath: String?) {
        Task {
            let snapshot = await Task.detached(priority: .utility) {
                ToolProbe.snapshot(spotdlPath: spotdlPath)
            }.value
            apply(snapshot)
        }
    }

    /// Upgrades spotDL with the tool that installed it, then refreshes the status.
    func updateSpotDL(spotdlPath: String?) {
        guard !isUpdating else { return }
        guard let command = ToolCheck.upgradeCommand(installer) else {
            updateMessage = "Update spotDL the same way you installed it."
            return
        }
        isUpdating = true
        updateMessage = nil
        let before = spotdlVersion
        Task {
            let run = await Task.detached(priority: .utility) {
                ToolProbe.run(command.executable, command.arguments)
            }.value
            let snapshot = await Task.detached(priority: .utility) {
                ToolProbe.snapshot(spotdlPath: spotdlPath)
            }.value
            apply(snapshot)
            isUpdating = false
            if run.status == 0 {
                if let after = snapshot.version {
                    updateMessage = after == before
                        ? "spotDL is already up to date (\(after))."
                        : "spotDL updated to \(after)."
                } else {
                    updateMessage = "spotDL updated."
                }
            } else {
                let reason = ToolProbe.lastLine(run.output) ?? ""
                updateMessage = reason.isEmpty ? "Update failed." : "Update failed: \(reason)"
            }
        }
    }

    private func apply(_ snapshot: ToolProbe.Snapshot) {
        spotdlVersion = snapshot.version
        ffmpegFound = snapshot.ffmpegFound
        installer = snapshot.installer
    }
}

/// Process and file work for ToolStatus. Called from detached tasks, never on the main actor.
private enum ToolProbe {
    struct Snapshot: Sendable {
        var version: String?
        var ffmpegFound: Bool
        var installer: ToolCheck.Installer
    }

    static func snapshot(spotdlPath: String?) -> Snapshot {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        // spotdl --download-ffmpeg puts its own copy in ~/.spotdl.
        let ffmpegFound = firstExecutable("ffmpeg", home: home) != nil
            || FileManager.default.isExecutableFile(atPath: "\(home)/.spotdl/ffmpeg")
        guard let spotdlPath else {
            return Snapshot(version: nil, ffmpegFound: ffmpegFound, installer: .unknown)
        }
        // Homebrew and uv link spotdl into their own folders, so the resolved path tells them apart.
        let resolved = URL(fileURLWithPath: spotdlPath).resolvingSymlinksInPath().path
        let installer = ToolCheck.installer(
            resolvedPath: resolved,
            uvPath: firstExecutable("uv", home: home),
            pipxPath: firstExecutable("pipx", home: home),
            brewPath: firstExecutable("brew", home: home)
        )
        let result = run(spotdlPath, ["--version"])
        let version = result.status == 0 ? ToolCheck.parseVersion(result.output) : nil
        return Snapshot(version: version, ffmpegFound: ffmpegFound, installer: installer)
    }

    static func run(_ executable: String, _ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = SpotDLCommand.environment(
            base: ProcessInfo.processInfo.environment,
            home: FileManager.default.homeDirectoryForCurrentUser.path
        )
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return (-1, error.localizedDescription)
        }
        // Read to the end before waiting, so a full pipe cannot stall the process.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    static func lastLine(_ output: String) -> String? {
        output.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last { !$0.isEmpty }
    }

    static func firstExecutable(_ name: String, home: String) -> String? {
        ToolCheck.toolCandidatePaths(name, home: home).first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
