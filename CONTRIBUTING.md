# Contributing to spotdl-gui

Thanks for helping out. This is a small project, so small, focused changes are the easiest to review.

## Prerequisites

- macOS 14 or later
- Command Line Tools (`xcode-select --install`) or Xcode
- spotDL and ffmpeg, for manual testing (see the README)

The app builds with plain `swiftc` through the Makefile. SwiftPM is not used.

## Commands

- `make test`: run the unit tests
- `make app`: build the universal app to `build/spotDL.app`
- `make install`: build and copy the app to `/Applications`
- `make dmg`: build the disk image and its checksum in `dist/`
- `make format`: format the sources with SwiftFormat (`brew install swiftformat`)

Run `make help` to see every target.

## Layout

- `Sources/Core`: pure logic, such as spotDL output parsing. No AppKit or SwiftUI. Changes here need tests.
- `Sources/App`: the SwiftUI window and process handling.
- `Tests`: unit tests, written with Swift Testing.
- `scripts`: helper scripts for the app icon and the disk image.
- `Resources/Info.plist`: the app's bundle info. The version comes from `VERSION`.

## Testing with real spotDL output

The unit tests do not call spotDL. To check a change against real spotDL output, build the app and run the binary directly:

1. `make app`
2. Launch it from a terminal with a scratch save folder:

   ```bash
   SPOTDL_GUI_OUTDIR="$HOME/Desktop/spotdl-test" build/spotDL.app/Contents/MacOS/spotDL
   ```

3. Optional: set `SPOTDL_GUI_AUTOADD` to a link or search to queue it on launch.

This downloads real music. Use a scratch folder and a short album or playlist, not your music library.

## Pull requests

- Keep each pull request small and about one thing.
- Run `make test` and `make app` first, then try the change in the app.
- If the change is user facing, add a line to `CHANGELOG.md` under `## [Unreleased]`.
- Fill in the pull request template.

## Releasing (maintainers)

1. Bump `VERSION`.
2. In `CHANGELOG.md`, rename `## [Unreleased]` to `## [x.y.z] - YYYY-MM-DD`, then add a new `## [Unreleased]` heading above it.
3. Commit and push.
4. Run `make release`. It needs the GitHub CLI (`brew install gh`).

`make release` stops if the tree is dirty, if there are unpushed commits, if the tag already exists or if `CHANGELOG.md` has no section for the version. Otherwise it runs the tests, builds the disk image and publishes the GitHub release with its checksum file.

The app is ad-hoc signed, not notarized. Users see the first-launch step described in the README.
