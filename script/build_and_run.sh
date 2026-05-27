#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="LocalSidebar"
BUNDLE_ID="app.localsidebar"
MIN_SYSTEM_VERSION="26.5"
SIGN_IDENTITY="${LOCALSIDEBAR_SIGN_IDENTITY:-LocalSidebar Dev}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
RESTORER_NAME="LocalSidebarDockRestorer"
RESTORER_BINARY="$APP_MACOS/$RESTORER_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

cd "$ROOT_DIR"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"
BUILD_RESTORER="$(swift build --show-bin-path)/$RESTORER_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$BUILD_RESTORER" "$RESTORER_BINARY"
chmod +x "$APP_BINARY"
chmod +x "$RESTORER_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>LocalSidebar uses Apple Events to read Finder Trash state and control Music or Spotify media playback when available.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

sign_app() {
  if security find-identity -v -p codesigning | grep -Fq "$SIGN_IDENTITY"; then
    codesign --force --sign "$SIGN_IDENTITY" "$RESTORER_BINARY"
    codesign --force --identifier "$BUNDLE_ID" --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
  else
    echo "warning: '$SIGN_IDENTITY' not found; using ad-hoc signing. Accessibility resets on rebuild (see README)." >&2
  fi
}

open_app() {
  local open_args=(-n)
  if [[ -n "${LOCALSIDEBAR_DEBUG_BADGES:-}" ]]; then
    open_args+=(--env "LOCALSIDEBAR_DEBUG_BADGES=$LOCALSIDEBAR_DEBUG_BADGES")
  fi

  /usr/bin/open "${open_args[@]}" "$APP_BUNDLE"
}

sign_app

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    echo "$APP_NAME is running"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
