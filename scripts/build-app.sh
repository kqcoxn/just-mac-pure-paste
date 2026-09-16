#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
APP_VERSION="${APP_VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' scripts/Info.plist)}"
APP_BUILD_NUMBER="${APP_BUILD_NUMBER:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' scripts/Info.plist)}"
[[ "$APP_VERSION" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || { echo 'APP_VERSION must be MAJOR.MINOR.PATCH' >&2; exit 1; }
[[ "$APP_BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || { echo 'APP_BUILD_NUMBER must be a positive integer' >&2; exit 1; }
./scripts/swift.sh build -c release
BIN_DIR="$(./scripts/swift.sh build -c release --show-bin-path | tail -n 1)"
mkdir -p "$PROJECT_ROOT/dist"
STAGING_DIR="$(mktemp -d "$PROJECT_ROOT/dist/build.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
APP_DIR="$STAGING_DIR/Just Pure Paste.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/JustPurePaste" "$APP_DIR/Contents/MacOS/JustPurePaste"
for bundle in "$BIN_DIR"/*.bundle; do
    [ -d "$bundle" ] || continue
    ditto "$bundle" "$APP_DIR/Contents/Resources/$(basename "$bundle")"
done
cp "$PROJECT_ROOT/.build/checkouts/KeyboardShortcuts/license" "$APP_DIR/Contents/Resources/KeyboardShortcuts-LICENSE.txt"
cp "$PROJECT_ROOT/scripts/Info.plist" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $APP_BUILD_NUMBER" "$APP_DIR/Contents/Info.plist"
codesign --force --sign - "$APP_DIR"
codesign --verify --strict "$APP_DIR"
# Replace only this project's generated artifact after the new bundle verifies.
rm -rf "$PROJECT_ROOT/dist/Just Pure Paste.app"
mv "$APP_DIR" "$PROJECT_ROOT/dist/Just Pure Paste.app"
printf 'Built: %s\n' "$PROJECT_ROOT/dist/Just Pure Paste.app"
