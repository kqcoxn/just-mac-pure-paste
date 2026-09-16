#!/bin/bash
# Build fully before stopping and replacing the installed development copy.
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$PROJECT_ROOT/scripts/build-app.sh" --development
INSTALL_DIR="$HOME/Applications"
APP_PATH="$INSTALL_DIR/Just Pure Paste Dev.app"
mkdir -p "$INSTALL_DIR"
if [[ -e "$APP_PATH" ]]; then
    EXISTING_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist")"
    [[ "$EXISTING_ID" == com.justmacpurepaste.app.dev ]] || { echo 'Refusing to replace an unrelated application.' >&2; exit 1; }
fi
INSTALL_TEMP="$(mktemp -d "$INSTALL_DIR/.jpp-dev.XXXXXX")"
trap 'rm -rf "$INSTALL_TEMP"' EXIT
ditto "$PROJECT_ROOT/dist/development/Just Pure Paste Dev.app" "$INSTALL_TEMP/Just Pure Paste Dev.app"
codesign --verify --strict "$INSTALL_TEMP/Just Pure Paste Dev.app"
# Match the full executable path, not another app with the same executable name.
python3 - "$APP_PATH/Contents/MacOS/JustPurePaste" <<'PY'
import os, signal, subprocess, sys, time
path = sys.argv[1]
rows = subprocess.check_output(['ps', '-axo', 'pid=,comm='], text=True).splitlines()
pids = [int(row.strip().split(None, 1)[0]) for row in rows
        if len(row.strip().split(None, 1)) == 2 and row.strip().split(None, 1)[1] == path]
for pid in pids:
    try: os.kill(pid, signal.SIGTERM)
    except ProcessLookupError: pass
for _ in range(100):
    alive = []
    for pid in pids:
        try: os.kill(pid, 0); alive.append(pid)
        except ProcessLookupError: pass
    if not alive: break
    time.sleep(0.1)
else:
    sys.exit('Development app did not exit; installed bundle was not replaced.')
PY
rm -rf "$APP_PATH"
mv "$INSTALL_TEMP/Just Pure Paste Dev.app" "$APP_PATH"
open "$APP_PATH"
printf 'Running: %s\n' "$APP_PATH"
