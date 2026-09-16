#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
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
codesign --force --sign - "$APP_DIR"
codesign --verify --strict "$APP_DIR"
# Replace only this project's generated artifact after the new bundle verifies.
rm -rf "$PROJECT_ROOT/dist/Just Pure Paste.app"
mv "$APP_DIR" "$PROJECT_ROOT/dist/Just Pure Paste.app"
printf 'Built: %s\n' "$PROJECT_ROOT/dist/Just Pure Paste.app"
