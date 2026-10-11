#!/bin/bash
# Renders real SwiftUI/AppKit views using fixtures. Never runs cleanup.
set -euo pipefail
TASK_ROOT=$(cd "$(dirname "$0")/.." && pwd)
TASK_BUILD=$(mktemp -d /tmp/husk-ui-smoke.XXXXXX)
trap 'rm -rf "$TASK_BUILD"' EXIT
TASK_OUTPUT=${1:-/tmp/husk-ui-snapshots}
mkdir -p "$TASK_BUILD/HuskUISmoke.app/Contents/MacOS" "$TASK_BUILD/HuskUISmoke.app/Contents/Resources"
TASK_SOURCES=()
while IFS= read -r source; do
    [[ "$source" == */HuskApp.swift ]] && continue
    TASK_SOURCES+=("$source")
done < <(rg --files "$TASK_ROOT/Husk/Husk" -g '*.swift')
xcrun swiftc -swift-version 6 -parse-as-library "${TASK_SOURCES[@]}" "$TASK_ROOT/scripts/ui-smoke.swift" -o "$TASK_BUILD/HuskUISmoke.app/Contents/MacOS/HuskUISmoke"
# Bundle the brand asset when a Debug build is available.
TASK_ASSETS=${HUSK_UI_ASSETS:-/tmp/husk-ui-build/Build/Products/Debug/Husk.app/Contents/Resources/Assets.car}
if [[ -f "$TASK_ASSETS" ]]; then cp "$TASK_ASSETS" "$TASK_BUILD/HuskUISmoke.app/Contents/Resources/Assets.car"; fi
cat > "$TASK_BUILD/HuskUISmoke.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleExecutable</key><string>HuskUISmoke</string><key>CFBundleIdentifier</key><string>dev.husk.UISmoke</string><key>CFBundlePackageType</key><string>APPL</string></dict></plist>
PLIST
HUSK_UI_SMOKE=1 "$TASK_BUILD/HuskUISmoke.app/Contents/MacOS/HuskUISmoke" "$TASK_OUTPUT"
