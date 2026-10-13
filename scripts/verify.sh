#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root/Husk"
verification_root=${HUSK_VERIFY_ROOT:-${TMPDIR:-/tmp}/husk-verification}
python3 "$repo_root/scripts/check-repository.py"
python3 "$repo_root/scripts/test-release-source.py"
swift test --scratch-path "$verification_root/swift"
xcodebuild -project Husk.xcodeproj -scheme Husk -configuration Debug \
  -derivedDataPath "$verification_root/xcode" CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Husk.xcodeproj -scheme Husk -configuration Release \
  -derivedDataPath "$verification_root/xcode" CODE_SIGNING_ALLOWED=NO \
  'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO build
for configuration in Debug Release; do
  resources="$verification_root/xcode/Build/Products/$configuration/Husk.app/Contents/Resources"
  cmp "$repo_root/LICENSE" "$resources/Husk-LICENSE.txt"
  cmp "$repo_root/Vendor/TourKit/LICENSE" "$resources/TourKit-LICENSE.txt"
done
# Release archives have no Git metadata. Source checks run before archiving.
if [[ -e "$repo_root/.git" ]]; then
  git diff --check
  git diff --cached --check
fi
