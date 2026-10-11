#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root/Husk"
swift test
for configuration in Debug Release; do
  xcodebuild -project Husk.xcodeproj -scheme Husk -configuration "$configuration" \
    -derivedDataPath "${TMPDIR:-/tmp}/husk-verification" CODE_SIGNING_ALLOWED=NO build
done
git diff --check
git diff --cached --check
