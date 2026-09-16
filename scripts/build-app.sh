#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
MODE="${1:---development}"
case "$MODE" in
    --development)
        SIGNING_IDENTITY="${DEV_SIGNING_IDENTITY:-Just Pure Paste Local Development}"
        APP_NAME='Just Pure Paste Dev'
        OUTPUT_DIR="$PROJECT_ROOT/dist/development"
        if ! security find-identity -v -p codesigning | grep -Fq "\"$SIGNING_IDENTITY\""; then
            echo 'Development signing identity missing. Run ./scripts/setup-dev-signing.sh, or set DEV_SIGNING_IDENTITY to your certificate name.' >&2
            exit 1
        fi
        ;;
    --release)
        SIGNING_IDENTITY='-'
        APP_NAME='Just Pure Paste'
        OUTPUT_DIR="$PROJECT_ROOT/dist"
        ;;
    *) echo 'Usage: build-app.sh [--development|--release]' >&2; exit 1 ;;
esac
APP_VERSION="${APP_VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' scripts/Info.plist)}"
APP_BUILD_NUMBER="${APP_BUILD_NUMBER:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' scripts/Info.plist)}"
[[ "$APP_VERSION" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || { echo 'APP_VERSION must be MAJOR.MINOR.PATCH' >&2; exit 1; }
[[ "$APP_BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || { echo 'APP_BUILD_NUMBER must be a positive integer' >&2; exit 1; }
APP_RELEASE_TAG="${APP_RELEASE_TAG:-v$APP_VERSION}"
TAG_VERSION="$(python3 scripts/release-info.py "$APP_RELEASE_TAG" | sed -n 's/^version=//p')"
[[ "$TAG_VERSION" == "$APP_VERSION" ]] || { echo 'APP_RELEASE_TAG and APP_VERSION mismatch' >&2; exit 1; }
./scripts/swift.sh build -c release
BIN_DIR="$(./scripts/swift.sh build -c release --show-bin-path | tail -n 1)"
mkdir -p "$PROJECT_ROOT/dist"
STAGING_DIR="$(mktemp -d "$PROJECT_ROOT/dist/build.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
APP_DIR="$STAGING_DIR/$APP_NAME.app"
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
/usr/libexec/PlistBuddy -c "Add :JPPReleaseTag string $APP_RELEASE_TAG" "$APP_DIR/Contents/Info.plist"
if [[ "$MODE" == --development ]]; then
    /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.justmacpurepaste.app.dev' "$APP_DIR/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$APP_DIR/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$APP_DIR/Contents/Info.plist"
fi
codesign --force --sign "$SIGNING_IDENTITY" "$APP_DIR"
codesign --verify --strict "$APP_DIR"
# Replace only this project's generated artifact after the new bundle verifies.
mkdir -p "$OUTPUT_DIR"
rm -rf "$OUTPUT_DIR/$APP_NAME.app"
mv "$APP_DIR" "$OUTPUT_DIR/$APP_NAME.app"
printf 'Built: %s\n' "$OUTPUT_DIR/$APP_NAME.app"
