import AppKit
import Combine

@MainActor
final class Downloader: ObservableObject {
    static let shared = Downloader()

    @Published var jobs: [Job] = []
    @Published var outputDir: URL {
        didSet { if !outputOverridden { UserDefaults.standard.set(outputDir.path, forKey: "outputDir") } }
    }

    let spotdlPath: String?
    private let outputOverridden: Bool
    private var askedForNotifications = false

    init() {
        let env = ProcessInfo.processInfo.environment
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

        // History is saved newest first, the same order as `jobs`.
        jobs = HistoryStore.load().map { Job(record: $0) }

        ToolStatus.shared.refresh(spotdlPath: spotdlPath)
        AppUpdateChecker.shared.checkIfDue()

        if let auto = env["SPOTDL_GUI_AUTOADD"], !auto.isEmpty {
            DispatchQueue.main.async { self.add(auto) }
        }
        // Test runs (SPOTDL_GUI_OUTDIR set) skip it, so they do not sync the real playlists.
        if !outputOverridden, SettingsStore.shared.syncOnLaunch {
            DispatchQueue.main.async { self.syncAll() }
        }
    }

    var activeCount: Int { jobs.filter { $0.state.isActive }.count }
    var hasFinished: Bool { jobs.contains { !$0.state.isActive } }

    /// Accepts one search term, or one or more links separated by spaces/new lines.
    func add(_ text: String) {
        let queries = QueryInput.queries(from: text)
        guard !queries.isEmpty else { return }
        let options = SettingsStore.shared.options
        for q in queries {
            let job = Job(query: q, options: options, outputDir: outputDir)
            jobs.insert(job, at: 0)
            loadArtwork(for: job)
        }
        requestNotificationsOnce()
        pump()
    }

    /// Queues a sync of a saved playlist, unless that playlist is already queued or running.
    func sync(_ playlist: SyncedPlaylist) {
        guard !jobs.contains(where: { $0.state.isActive && $0.syncedPlaylist?.id == playlist.id }) else { return }
        let job = Job(query: playlist.url, options: SettingsStore.shared.options,
                      outputDir: URL(fileURLWithPath: playlist.outputDir, isDirectory: true), mode: .sync(playlist))
        jobs.insert(job, at: 0)
        loadArtwork(for: job)
        requestNotificationsOnce()
        pump()
    }

    func syncAll() {
        for playlist in SyncStore.shared.playlists { sync(playlist) }
    }

    /// Downloads one failed song again from the YouTube link the user picked.
    /// `query` is MatchFix.query's "<youtube>|<spotify>". The song goes into the list's folder.
    func fixMatch(in job: Job, query: String) {
        job.fixingSong = nil
        let fixed = Job(query: query, options: job.options, outputDir: job.folder)
        fixed.artworkURL = job.kind == .track ? job.artworkURL : nil
        jobs.insert(fixed, at: 0)
        pump()
    }

    /// Saves a finished album, playlist or artist download as a synced playlist. It syncs from the Synced playlists list.
    /// The playlist keeps the job's own options, since those are what its files were downloaded with.
    func keepInSync(_ job: Job) {
        _ = SyncStore.shared.add(url: job.query, title: job.run.listName ?? job.title, outputDir: job.outputDir,
                                 options: job.options)
    }

    func saveHistory() {
        HistoryStore.save(jobs.map { $0.record })
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
        let fresh = Job(query: job.query, options: job.options, outputDir: job.outputDir, mode: job.mode)
        fresh.artworkURL = job.artworkURL
        jobs[i] = fresh
        if fresh.artworkURL == nil { loadArtwork(for: fresh) }
        pump()
    }

    func remove(_ job: Job) {
        if job.state.isActive { cancel(job) }
        jobs.removeAll { $0.id == job.id }
        updateBadge()
        saveHistory()
    }

    func clearFinished() {
        jobs.removeAll { !$0.state.isActive }
        saveHistory()
    }

    func cancelAll() {
        for j in jobs where j.state.isActive { cancel(j) }
    }

    private func loadArtwork(for job: Job) {
        guard QueryInput.isSpotifyLink(job.query) else { return }
        Task {
            if let url = await ArtworkLoader.fetch(for: job.query) { job.artworkURL = url }
        }
    }

    /// Asks once per launch, the first time something is queued, so the prompt is not the first thing seen.
    private func requestNotificationsOnce() {
        guard !askedForNotifications else { return }
        askedForNotifications = true
        Notifier.requestAuthorizationIfNeeded()
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

        let arguments: [String]
        let workDir: URL
        if let saved = job.syncedPlaylist {
            // The list may have changed (for example "Remove songs taken off the playlist") since this job was queued.
            // If it was removed, do not run it: that would recreate its save file.
            guard let playlist = SyncStore.shared.playlists.first(where: { $0.id == saved.id }) else {
                job.state = .failed("This playlist is no longer synced.")
                pump()
                return
            }
            workDir = URL(fileURLWithPath: playlist.outputDir, isDirectory: true)
            arguments = SpotDLCommand.syncArguments(
                playlist: playlist,
                saveFileExists: FileManager.default.fileExists(atPath: playlist.saveFilePath),
                options: job.options
            )
        } else {
            workDir = job.outputDir
            arguments = SpotDLCommand.arguments(query: job.query, kind: job.kind, options: job.options)
        }

        do {
            try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        } catch {
            job.state = .failed("Cannot create the save folder: \(error.localizedDescription)")
            pump()
            return
        }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: spotdlPath)
        p.arguments = arguments
        p.currentDirectoryURL = workDir
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
        notifyFinished(job)
        if job.state == .done, SettingsStore.shared.addToMusicAutomatically {
            MusicLibrary.add(job.newFiles)
        }
        if job.state == .done, let playlist = job.syncedPlaylist {
            SyncStore.shared.markSynced(playlist.id, title: job.run.listName)
        }
        saveHistory()
        pump()
    }

    /// Cancelled jobs were stopped by the user, so they get no notification.
    private func notifyFinished(_ job: Job) {
        switch job.state {
        case .done:
            let summary = job.doneSummary
            Notifier.jobFinished(title: job.title, body: summary.isEmpty ? "Done" : summary)
        case .failed(let message):
            Notifier.jobFinished(title: job.title, body: "Failed: \(message)")
        default:
            break
        }
    }

    private func updateBadge() {
        let n = activeCount
        NSApp?.dockTile.badgeLabel = n > 0 ? "\(n)" : nil
    }
}
