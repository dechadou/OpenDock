# OpenDock

OpenDock is a local-first macOS sidebar for launching apps, organizing shortcuts,
switching windows, checking widgets, and keeping Dock-style controls close to the
edge of your screen.

## For People Using the App

### Download

Download the latest beta from the
[OpenDock releases page](https://github.com/dechadou/OpenDock/releases).

Current beta:
[v.0.0.1-beta](https://github.com/dechadou/OpenDock/releases/tag/v.0.0.1-beta)

### Requirements

- macOS 26.5 or newer.
- The current beta download is built for Apple Silicon Macs.

### Install

1. Download `OpenDock-v.0.0.1-beta-macos.zip` from the release page.
2. Unzip it.
3. Move `OpenDock.app` to `/Applications`.
4. Open the app.

This beta is not notarized yet, so macOS may block the first launch. If that
happens, open System Settings > Privacy & Security and allow OpenDock from
there.

### What OpenDock Does

- Keeps a compact sidebar on the screen edge.
- Shows running apps and lets you activate or switch between them.
- Stores apps, files, folders, URLs, stacks, and widgets locally.
- Supports drag and drop from Finder.
- Includes folder peeks, stacks, Trash, date/time, and media controls.
- Includes a launcher for apps in `/Applications`, `/System/Applications`, and
  `~/Applications`.
- Adds hover previews and a window switcher, with fallbacks when permissions are
  missing.
- Can mirror Dock-style app notification badges when macOS exposes them.
- Can hide the macOS Dock while OpenDock runs, with explicit Apply/Revert
  controls.

### Permissions

OpenDock works without extra permissions, but some features run in a degraded
mode until permissions are enabled.

- Accessibility: improves window activation and close actions, enables moving
  windows between displays, and improves Dock badge mirroring.
- Screen Recording: enables window thumbnails in hover previews and the window
  switcher.

You can manage these in System Settings > Privacy & Security.

### Shortcuts

- `Command-Option-S`: show or hide the sidebar.
- `Command-Option-Space`: open the app launcher.
- `Command-Option-W`: open the window switcher.

## For Developers

OpenDock is built with SwiftPM, SwiftUI, and small AppKit bridges. It is a local
macOS app with no server dependency.

### Requirements

- macOS 26.5 or newer.
- Swift 6.0 or newer from Xcode or the Command Line Tools.

### Clone

```bash
git clone https://github.com/dechadou/OpenDock.git
cd OpenDock
```

### Build and Run

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

### Build Without Launching

Use this when preparing release artifacts or checking compilation only:

```bash
swift build
swift build -c release
```

### Test

The project uses a standalone Swift unit-test runner:

```bash
./script/run_unit_tests.sh
```

### Development Signing

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

### Project Layout

- `Package.swift`: Swift package definition and executable targets.
- `Sources/OpenDock`: shared app models, services, stores, views, and layout
  support.
- `Sources/OpenDockApp`: app entry point.
- `Sources/OpenDockDockRestorer`: helper executable used when restoring Dock
  visibility.
- `Tests/OpenDockUnitTests`: standalone unit tests.
- `script`: local build, launch, and test helpers.
