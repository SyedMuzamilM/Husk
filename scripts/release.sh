#!/bin/bash
# Local build/sign/notarize only. Does not upload to a release or publish source.
set -euo pipefail
: "${HUSK_SIGNING_IDENTITY:?Set a Developer ID Application identity from your local keychain}"
: "${HUSK_TEAM_ID:?Set your release team ID}"
: "${HUSK_NOTARY_PROFILE:?Set a preconfigured notarytool keychain profile name}"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
source_revision="$(bash "$repo_root/scripts/prepare-release-source.sh" "$repo_root")"
release_root="$(mktemp -d "${TMPDIR:-/tmp}/husk-release.XXXXXX")"
snapshot_revision="$(bash "$repo_root/scripts/prepare-release-source.sh" "$repo_root" "$release_root/source")"
if [[ "$snapshot_revision" != "$source_revision" ]]; then
  echo "Release blocked: source revision changed while preparing the snapshot." >&2
  exit 1
fi
cd "$release_root/source"
HUSK_VERIFY_ROOT="$release_root/verification" ./scripts/verify.sh
app_path="$release_root/verification/xcode/Build/Products/Release/Husk.app"
if [[ "$(bash "$repo_root/scripts/prepare-release-source.sh" "$repo_root")" != "$source_revision" ]]; then
  echo "Release blocked: source changed during verification." >&2
  exit 1
fi
version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app_path/Contents/Info.plist")"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?$ ]]; then
  echo "Release blocked: invalid release version." >&2
  exit 1
fi
cp LICENSE "$app_path/Contents/Resources/Husk-LICENSE.txt"
printf '%s\n' "$source_revision" > "$app_path/Contents/Resources/SOURCE_REVISION"
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
artifact="$release_root/Husk-$version.zip"
ditto -c -k --keepParent "$app_path" "$artifact"
if [[ "$(bash "$repo_root/scripts/prepare-release-source.sh" "$repo_root")" != "$source_revision" ]]; then
  echo "Release blocked: source changed during verification." >&2
  exit 1
fi
printf '%s\n' "$source_revision" > "$release_root/SOURCE_REVISION"
cp LICENSE "$release_root/LICENSE"
(cd "$release_root" && shasum -a 256 "Husk-$version.zip" > SHA256SUMS)
echo "Verified local artifact: $artifact"
