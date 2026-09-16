#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
LABEL="${1:?Usage: package-release.sh LABEL ARCH}"
ARCH="${2:?Usage: package-release.sh LABEL ARCH}"
[[ "$LABEL" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]] || { echo 'Invalid archive label' >&2; exit 1; }
[[ "$ARCH" == arm64 || "$ARCH" == x86_64 ]] || { echo 'Unsupported architecture' >&2; exit 1; }
APP_DIR="$PROJECT_ROOT/dist/Just Pure Paste.app"
BINARY="$APP_DIR/Contents/MacOS/JustPurePaste"
if [[ "$LABEL" == v* ]]; then
    VERSION="$(python3 scripts/release-info.py "$LABEL" | sed -n 's/^version=//p')"
    ACTUAL_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")"
    [[ "$ACTUAL_VERSION" == "$VERSION" ]] || { echo 'Tag and app version mismatch' >&2; exit 1; }
fi
[[ "$(lipo -archs "$BINARY")" == "$ARCH" ]] || { echo 'Binary architecture mismatch' >&2; exit 1; }
codesign --verify --strict "$APP_DIR"
ARCHIVE="JustPurePaste-${LABEL}-macos-${ARCH}.zip"
STAGING_DIR="$(mktemp -d "$PROJECT_ROOT/dist/archive.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
# ditto preserves executable permissions, bundle layout, and macOS metadata.
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$STAGING_DIR/$ARCHIVE"
ditto -x -k "$STAGING_DIR/$ARCHIVE" "$STAGING_DIR/unpacked"
UNPACKED_APP="$STAGING_DIR/unpacked/Just Pure Paste.app"
codesign --verify --strict "$UNPACKED_APP"
test -x "$UNPACKED_APP/Contents/MacOS/JustPurePaste"
test -d "$UNPACKED_APP/Contents/Resources/KeyboardShortcuts_KeyboardShortcuts.bundle"
test -f "$UNPACKED_APP/Contents/Resources/KeyboardShortcuts-LICENSE.txt"
mv "$STAGING_DIR/$ARCHIVE" "$PROJECT_ROOT/dist/$ARCHIVE"
cd "$PROJECT_ROOT/dist"
shasum -a 256 "$ARCHIVE" > "${ARCHIVE}.sha256"
printf 'Archive: %s\n' "$PROJECT_ROOT/dist/$ARCHIVE"
