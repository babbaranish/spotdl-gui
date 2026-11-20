# Changelog

All notable changes to this project are listed here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.1.0] - 2026-11-20

### Added

- Checks that spotDL and ffmpeg are installed, and can update spotDL from the app.
- Playlist sync: keep a playlist or album folder up to date. Optionally remove songs that were taken off the playlist.
- A Settings window for format, synced lyrics, audio source, cookies file, file name template and more.
- A notification when a download finishes.
- Fix a wrong match: paste the right YouTube link for a song that downloaded the wrong track.
- Drag and drop Spotify links onto the window.
- Album art in the job list.
- Add to Music: send finished songs to Apple Music, automatically or from a job's menu.
- Saved queue and history: jobs stay in the list after you quit, and you can retry them.
- Checks for a newer spotdl-gui release and tells you when one is out.
- Install with Homebrew: `brew install --cask babbaranish/tap/spotdl-gui`.

## [1.0.0] - 2026-11-20

### Added

- Native macOS window for spotDL: paste a Spotify song, album, playlist or artist link, or type a song name.
- Download queue that runs one job at a time to avoid Spotify rate limits.
- Paste several links at once.
- MP3 (320 kbps), M4A (original audio) and FLAC.
- Live progress per job and a per-song list (finished, already downloaded, failed).
- Retry re-downloads only the missing songs.
- Clipboard prefill when you come back with a Spotify link copied.
- Playlists and albums get their own folder; choose where files are saved.
- Dock badge, finish sound and a warning before quitting mid-download.
- Universal build (Apple Silicon and Intel) shipped as a .dmg.

[Unreleased]: https://github.com/babbaranish/spotdl-gui/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/babbaranish/spotdl-gui/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/babbaranish/spotdl-gui/releases/tag/v1.0.0
