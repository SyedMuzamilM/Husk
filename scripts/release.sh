#!/bin/bash
# Local build/sign/notarize only. Does not upload to a release or publish source.
set -euo pipefail
: "${HUSK_SIGNING_IDENTITY:?Set a Developer ID Application identity from your local keychain}"
: "${HUSK_TEAM_ID:?Set your release team ID}"
: "${HUSK_NOTARY_PROFILE:?Set a preconfigured notarytool keychain profile name}"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
if [[ ! -f LICENSE ]]; then
  echo "Release blocked: choose a license and verify source/asset rights first." >&2
  exit 1
fi
if ! git ls-files --error-unmatch LICENSE >/dev/null 2>&1; then
  echo "Release blocked: LICENSE must be committed." >&2
  exit 1
fi
source_revision="$(git rev-parse HEAD)"
if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  echo "Release blocked: tracked changes must be committed." >&2
  exit 1
fi
./scripts/verify.sh
release_root="$(mktemp -d "${TMPDIR:-/tmp}/husk-release.XXXXXX")"
xcodebuild -project Husk/Husk.xcodeproj -scheme Husk -configuration Release \
  -derivedDataPath "$release_root/build" CODE_SIGNING_ALLOWED=NO ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO build
app_path="$release_root/build/Build/Products/Release/Husk.app"
codesign --force --options runtime --timestamp --sign "$HUSK_SIGNING_IDENTITY" "$app_path"
codesign --verify --deep --strict --verbose=2 "$app_path"
actual_team="$(codesign -dv --verbose=4 "$app_path" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
if [[ "$actual_team" != "$HUSK_TEAM_ID" ]]; then
  echo "Release blocked: signature team does not match HUSK_TEAM_ID." >&2
  exit 1
fi
ditto -c -k --keepParent "$app_path" "$release_root/Husk-notarize.zip"
xcrun notarytool submit "$release_root/Husk-notarize.zip" --keychain-profile "$HUSK_NOTARY_PROFILE" --wait
xcrun stapler staple "$app_path"
xcrun stapler validate "$app_path"
spctl --assess --type execute --verbose=2 "$app_path"
version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app_path/Contents/Info.plist")"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?$ ]]; then
  echo "Release blocked: invalid release version." >&2
  exit 1
fi
artifact="$release_root/Husk-$version.zip"
ditto -c -k --keepParent "$app_path" "$artifact"
if [[ "$(git rev-parse HEAD)" != "$source_revision" || -n "$(git status --porcelain --untracked-files=no)" ]]; then
  echo "Release blocked: source changed during verification." >&2
  exit 1
fi
printf '%s\n' "$source_revision" > "$release_root/SOURCE_REVISION"
(cd "$release_root" && shasum -a 256 "Husk-$version.zip" > SHA256SUMS)
echo "Verified local artifact: $artifact"
