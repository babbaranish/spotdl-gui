import AppKit
import Combine

@MainActor
final class Downloader: ObservableObject {
    static let shared = Downloader()

    @Published var jobs: [Job] = []
    @Published var format: AudioFormat {
        didSet { UserDefaults.standard.set(format.rawValue, forKey: "format") }
    }
    @Published var outputDir: URL {
        didSet { if !outputOverridden { UserDefaults.standard.set(outputDir.path, forKey: "outputDir") } }
    }

    let spotdlPath: String?
    private let outputOverridden: Bool

    init() {
        let env = ProcessInfo.processInfo.environment
        format = AudioFormat(rawValue: UserDefaults.standard.string(forKey: "format") ?? "") ?? .mp3
        if let override = env["SPOTDL_GUI_OUTDIR"] {
            outputDir = URL(fileURLWithPath: override, isDirectory: true)
            outputOverridden = true
        } else if let saved = UserDefaults.standard.string(forKey: "outputDir") {
            outputDir = URL(fileURLWithPath: saved, isDirectory: true)
            outputOverridden = false
        } else {
            let music = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music")
            outputDir = music.appendingPathComponent("spotDL", isDirectory: true)
            outputOverridden = false
        }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        spotdlPath = SpotDLCommand.candidatePaths(home: home)
            .first { FileManager.default.isExecutableFile(atPath: $0) }

        if let auto = env["SPOTDL_GUI_AUTOADD"], !auto.isEmpty {
            DispatchQueue.main.async { self.add(auto) }
        }
    }

    var activeCount: Int { jobs.filter { $0.state.isActive }.count }
    var hasFinished: Bool { jobs.contains { !$0.state.isActive } }

    /// Accepts one search term, or one or more links separated by spaces/new lines.
    func add(_ text: String) {
        let queries = QueryInput.queries(from: text)
        guard !queries.isEmpty else { return }
        for q in queries {
            jobs.insert(Job(query: q, format: format, outputDir: outputDir), at: 0)
        }
        pump()
    }

    func cancel(_ job: Job) {
        job.cancelRequested = true
        if let p = job.process, p.isRunning {
            p.interrupt()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { if p.isRunning { p.terminate() } }
        } else {
            job.state = .cancelled
            pump()
        }
        updateBadge()
    }

    func retry(_ job: Job) {
        guard let i = jobs.firstIndex(where: { $0.id == job.id }) else { return }
        jobs[i] = Job(query: job.query, format: job.format, outputDir: job.outputDir)
        pump()
    }

    func remove(_ job: Job) {
        if job.state.isActive { cancel(job) }
        jobs.removeAll { $0.id == job.id }
        updateBadge()
    }

    func clearFinished() {
        jobs.removeAll { !$0.state.isActive }
    }

    func cancelAll() {
        for j in jobs where j.state.isActive { cancel(j) }
    }

    /// Runs one job at a time (oldest first) to stay under Spotify's rate limits.
    private func pump() {
        updateBadge()
        guard !jobs.contains(where: { $0.process != nil }) else { return }
        guard let next = jobs.last(where: { $0.state == .waiting }) else { return }
        start(next)
    }

    private func start(_ job: Job) {
        guard let spotdlPath else {
            job.state = .failed("spotDL is not installed.")
            pump()
            return
        }
        do {
            try FileManager.default.createDirectory(at: job.outputDir, withIntermediateDirectories: true)
        } catch {
            job.state = .failed("Cannot create the save folder: \(error.localizedDescription)")
            pump()
            return
        }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: spotdlPath)
        p.arguments = SpotDLCommand.arguments(query: job.query, kind: job.kind, format: job.format)
        p.currentDirectoryURL = job.outputDir
        p.environment = SpotDLCommand.environment(
            base: ProcessInfo.processInfo.environment,
            home: FileManager.default.homeDirectoryForCurrentUser.path
        )

        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        let handle = pipe.fileHandleForReading
        // Output and exit are reported separately; the job finishes once both have happened,
        // so no output can arrive after the job is marked finished.
        handle.readabilityHandler = { h in
            let data = h.availableData
            if data.isEmpty {
                h.readabilityHandler = nil
                Task { @MainActor in
                    job.outputClosed = true
                    Downloader.shared.finishIfReady(job)
                }
            } else {
                Task { @MainActor in job.ingest(data) }
            }
        }
        p.terminationHandler = { proc in
            let code = proc.terminationStatus
            Task { @MainActor in
                job.exitCode = code
                Downloader.shared.finishIfReady(job)
                // If a leftover child keeps the pipe open, do not wait forever.
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                job.outputClosed = true
                Downloader.shared.finishIfReady(job)
            }
        }

        job.startedAt = Date()
        job.state = .fetching
        job.process = p
        do {
            try p.run()
        } catch {
            job.process = nil
            job.state = .failed("Could not start spotDL: \(error.localizedDescription)")
            pump()
        }
    }

    fileprivate func finishIfReady(_ job: Job) {
        guard !job.isFinished, job.outputClosed, let code = job.exitCode else { return }
        job.finish(exitCode: code)
        if job.state == .done { NSSound(named: "Glass")?.play() }
        pump()
    }

    private func updateBadge() {
        let n = activeCount
        NSApp?.dockTile.badgeLabel = n > 0 ? "\(n)" : nil
    }
}
