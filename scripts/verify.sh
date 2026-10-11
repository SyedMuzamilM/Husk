#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root/Husk"
swift test
xcodebuild -project Husk.xcodeproj -scheme Husk -configuration Debug \
  -derivedDataPath "${TMPDIR:-/tmp}/husk-verification" CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Husk.xcodeproj -scheme Husk -configuration Release \
  -derivedDataPath "${TMPDIR:-/tmp}/husk-verification" CODE_SIGNING_ALLOWED=NO \
  'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO build
git diff --check
git diff --cached --check
