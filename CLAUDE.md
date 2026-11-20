# spotdl-gui

Native macOS SwiftUI app wrapping the spotdl CLI. See CONTRIBUTING.md for layout and commands.

## Build and test

- `make test` / `make app` / `make dmg` - the only supported build. No Package.swift: SwiftPM can't link manifests on the local Command Line Tools (no Xcode installed), so never use `swift build` / `swift test`.
- `make release` publishes a GitHub release with `gh`. Only the user runs it.
- macOS make is 3.81: `.SHELLFLAGS` is ignored (use `set -e` in multi-command recipes) and mtimes are 1-second, so `touch` the file or `make clean` if a rebuild seems skipped.

## Code rules

- `Sources/Core` imports only Foundation; it is compiled into the test binary. UI, AppKit and Process code go in `Sources/App`.
- Each binary is one module (Core+App or Core+Tests): keep types `internal`, no `public` or `@testable`.
- No macros except Swift Testing's: the CLT lacks the `@State`/`@Observable` plugins, so use `ObservableObject` + `@StateObject` (see `InputModel`).
- Tests use Swift Testing (`import Testing`); XCTest is not available.

## Verifying UI

- `screencapture` fails here (no Screen Recording permission), so UI changes can't be checked visually. Launch `build/spotDL.app/Contents/MacOS/spotDL` with `SPOTDL_GUI_OUTDIR` set to a scratch folder, and say the UI was not seen.
