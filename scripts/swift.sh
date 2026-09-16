#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
COMMAND="${1:-build}"
if [ "$#" -gt 0 ]; then shift; fi
swift package resolve
DEVELOPER_PATH="$(xcode-select -p)"
if [[ "$DEVELOPER_PATH" == */CommandLineTools ]]; then
    # CLT does not ship SwiftUIMacros/PreviewsMacros. SDK 26 retains wrapper-based @State.
    SDK_PATH="$DEVELOPER_PATH/SDKs/MacOSX26.sdk"
    if [ ! -d "$SDK_PATH" ]; then
        printf 'Command Line Tools compatibility requires the macOS 26 SDK.\n' >&2
        exit 1
    fi
    python3 scripts/prepare-clt.py --clt
    if [ "$COMMAND" = test ]; then
        FRAMEWORK_PATH="$DEVELOPER_PATH/Library/Developer/Frameworks"
        EXTRA_FLAGS=(--disable-xctest -Xswiftc -F -Xswiftc "$FRAMEWORK_PATH"
            -Xswiftc -load-plugin-library -Xswiftc "$DEVELOPER_PATH/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
            -Xlinker -F -Xlinker "$FRAMEWORK_PATH"
            -Xlinker -rpath -Xlinker "$FRAMEWORK_PATH")
        exec swift "$COMMAND" --build-system native --sdk "$SDK_PATH" "${EXTRA_FLAGS[@]}" "$@"
    fi
    exec swift "$COMMAND" --build-system native --sdk "$SDK_PATH" "$@"
fi
python3 scripts/prepare-clt.py
exec swift "$COMMAND" "$@"
