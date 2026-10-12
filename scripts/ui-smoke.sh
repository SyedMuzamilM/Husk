#!/bin/bash
# Renders real SwiftUI/AppKit views using fixtures. Never runs cleanup.
set -euo pipefail
TASK_ROOT=$(cd "$(dirname "$0")/.." && pwd)
TASK_BUILD=$(mktemp -d /tmp/husk-ui-smoke.XXXXXX)
trap 'if [[ -n ${TASK_WINDOW_PID:-} ]]; then kill -TERM "$TASK_WINDOW_PID" 2>/dev/null || true; fi; rm -rf "$TASK_BUILD"' EXIT
TASK_OUTPUT=${1:-/tmp/husk-ui-snapshots}
if [[ "${HUSK_UI_WINDOW_ONLY:-0}" == 1 ]]; then
    # Build an isolated private app with the production App/Scene, plus a test-only observer.
    mkdir -p "$TASK_BUILD/source/Husk" "$TASK_BUILD/source/Vendor"
    cp -R "$TASK_ROOT/Husk/Husk" "$TASK_ROOT/Husk/Husk.xcodeproj" "$TASK_BUILD/source/Husk/"
    cp -R "$TASK_ROOT/Vendor/TourKit" "$TASK_BUILD/source/Vendor/"
    cp "$TASK_ROOT/scripts/window-smoke.swift" "$TASK_BUILD/source/Husk/Husk/WindowSmoke.swift"
    python3 - "$TASK_BUILD/source/Husk/Husk/HuskApp.swift" <<'PYTHON'
from pathlib import Path
import sys
path = Path(sys.argv[1])
source = path.read_text()
marker = 'struct HuskApp: App {'
assert source.count(marker) == 1
path.write_text(source.replace(marker, marker + '\n    init() { WindowSmoke.configure() }'))
PYTHON
    if ! xcodebuild -project "$TASK_BUILD/source/Husk/Husk.xcodeproj" -scheme Husk \
        -configuration Debug -derivedDataPath "$TASK_BUILD/xcode" CODE_SIGNING_ALLOWED=NO \
        PRODUCT_BUNDLE_IDENTIFIER=dev.husk.WindowSmoke PRODUCT_NAME=HuskWindowSmoke \
        build > "$TASK_BUILD/build.log" 2>&1; then
        tail -80 "$TASK_BUILD/build.log" >&2
        exit 1
    fi
    TASK_APP="$TASK_BUILD/xcode/Build/Products/Debug/HuskWindowSmoke.app"
    # Direct launch inherits the renderer's Screen Recording access; reopen creates the scene window.
    HUSK_UI_SMOKE=1 "$TASK_APP/Contents/MacOS/HuskWindowSmoke" "$TASK_BUILD/window-result.txt" > "$TASK_BUILD/window.log" 2>&1 &
    TASK_WINDOW_PID=$!
    sleep 1
    open "$TASK_APP"
    swift -e 'import AppKit; for app in NSRunningApplication.runningApplications(withBundleIdentifier: "dev.husk.WindowSmoke") where app.bundleURL?.path == CommandLine.arguments[1] { app.activate(options: .activateAllWindows) }' "$TASK_APP"
    open "$TASK_APP"
    for ((attempt=0; attempt<120; attempt++)); do
        [[ -f "$TASK_BUILD/window-result.txt" ]] && break
        sleep 0.5
    done
    if [[ ! -f "$TASK_BUILD/window-result.txt" ]]; then
        cat "$TASK_BUILD/window.log" >&2
        echo "FAIL window smoke app produced no result" >&2
        exit 1
    fi
    cat "$TASK_BUILD/window-result.txt"
    rg -q '^PASS window lifecycle$' "$TASK_BUILD/window-result.txt"
    exit
fi
mkdir -p "$TASK_BUILD/HuskUISmoke.app/Contents/MacOS" "$TASK_BUILD/HuskUISmoke.app/Contents/Resources"
TASK_SOURCES=()
while IFS= read -r source; do
    [[ "$source" == */HuskApp.swift ]] && continue
    TASK_SOURCES+=("$source")
done < <(rg --files "$TASK_ROOT/Husk/Husk" -g '*.swift')
xcrun swiftc -swift-version 6 -parse-as-library -emit-module -emit-library -static -module-name TourKit \
    "$TASK_ROOT/Vendor/TourKit/Sources/TourKit/TourKit.swift" \
    -emit-module-path "$TASK_BUILD/TourKit.swiftmodule" -o "$TASK_BUILD/libTourKit.a"
TASK_DRIVER="$TASK_ROOT/scripts/ui-smoke.swift"
xcrun swiftc -swift-version 6 -parse-as-library -I "$TASK_BUILD" -L "$TASK_BUILD" -lTourKit \
    "${TASK_SOURCES[@]}" "$TASK_DRIVER" -o "$TASK_BUILD/HuskUISmoke.app/Contents/MacOS/HuskUISmoke"
# Bundle the brand asset when a Debug build is available.
TASK_ASSETS=${HUSK_UI_ASSETS:-/tmp/husk-ui-build/Build/Products/Debug/Husk.app/Contents/Resources/Assets.car}
if [[ -f "$TASK_ASSETS" ]]; then cp "$TASK_ASSETS" "$TASK_BUILD/HuskUISmoke.app/Contents/Resources/Assets.car"; fi
cat > "$TASK_BUILD/HuskUISmoke.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleExecutable</key><string>HuskUISmoke</string><key>CFBundleIdentifier</key><string>dev.husk.UISmoke</string><key>CFBundlePackageType</key><string>APPL</string></dict></plist>
PLIST
HUSK_UI_SMOKE=1 "$TASK_BUILD/HuskUISmoke.app/Contents/MacOS/HuskUISmoke" "$TASK_OUTPUT"
