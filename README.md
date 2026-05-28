# OpenDock

OpenDock is a local-only macOS sidebar and dock-style app built with
SwiftPM, SwiftUI, and small AppKit bridges.

## Requirements

- macOS 26.5 or newer.
- Swift 6.0 or newer from Xcode or the Command Line Tools.

## Build and Run

```bash
./script/build_and_run.sh
```

The script builds the Swift package, stages the app bundle at
`dist/OpenDock.app`, signs it, and launches it.

To verify the staged app launches:

```bash
./script/build_and_run.sh --verify
```

Additional launch modes:

```bash
./script/build_and_run.sh --debug
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
```

## Test

The project uses a standalone Swift unit-test runner:

```bash
./script/run_unit_tests.sh
```

You can also run the package build directly:

```bash
swift build
```

## Development Signing

Stable development signing lets macOS keep the Accessibility permission across
rebuilds. Without it, ad-hoc signatures change on every rebuild and macOS treats
the app as a new binary.

Create the certificate once:

1. Open Keychain Access.
2. Choose Certificate Assistant > Create a Certificate.
3. Name it `OpenDock Dev`.
4. Set Identity Type to Self-Signed Root.
5. Set Certificate Type to Code Signing.
6. Create the certificate in your login keychain.

`./script/build_and_run.sh` uses `OpenDock Dev` by default. To use a different
signing identity:

```bash
OPENDOCK_SIGN_IDENTITY="Your Code Signing Identity" ./script/build_and_run.sh
```

After the first signed build, grant Accessibility once in System Settings. The
grant should persist across later rebuilds as long as the signing identity and
bundle identifier stay the same.

## Shortcuts

- `Command-Option-S`: show/hide the sidebar.
- `Command-Option-Space`: open the app launcher.
- `Command-Option-W`: open the window switcher.

## Current Scope

- Running app list via `NSWorkspace`.
- Apps, files, folders, URLs, stacks, and system widgets persisted locally.
- App launcher for `/Applications`, `/System/Applications`, and `~/Applications`.
- One floating sidebar per display by default.
- Auto-hide on mouse-edge proximity, with exact-edge reveal and configurable delay for bottom placement.
- Settings for edge, bottom reveal delay, icon size, spacing, opacity, auto-hide, and displays.
- Settings for opening at login and hiding the macOS Dock while OpenDock runs, with explicit Apply/Revert for layout changes.
- Menu bar controls for pins, settings, refresh, and quit.
- Drag/drop from Finder plus sidebar item reordering.
- Stacks with popover contents, drag/drop from running apps/Finder/pins, and move-out support.
- Folder peek for folder items.
- Second-click behavior for active apps.
- Window switcher and hover previews, with title-only fallback when permissions are missing.
- AppKit-backed context-menu `Move To` actions for moving app windows between active displays.
- Dock-like app notification badges when Accessibility exposes them.
- Trash, date/time, and media-control widgets.

## Permissions

Window features work in a degraded mode without permissions. Enable:

- Accessibility: improves window activation and close actions, is required for moving windows between displays, and enables best-effort Dock badge mirroring.
- Screen Recording: enables window thumbnails in previews and the switcher.

## Project Layout

- `Package.swift`: Swift package definition and executable targets.
- `Sources/OpenDock`: shared app models, services, stores, views, and layout support.
- `Sources/OpenDockApp`: app entry point.
- `Sources/OpenDockDockRestorer`: helper executable used when restoring Dock visibility.
- `Tests/OpenDockUnitTests`: standalone unit tests.
- `script`: local build, launch, and test helpers.
