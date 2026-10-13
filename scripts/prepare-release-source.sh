#!/bin/bash
# Check a committed release revision, then optionally archive its tracked files.
set -euo pipefail
repo_root=${1:?Usage: prepare-release-source.sh REPOSITORY [NEW_SOURCE_DIRECTORY]}
source_revision=$(git -C "$repo_root" rev-parse HEAD)
if ! git -C "$repo_root" cat-file -e "$source_revision:LICENSE" 2>/dev/null; then
  echo "Release blocked: LICENSE must exist in the committed revision." >&2
  exit 1
fi
# Git archives omit submodule contents. Reject them until snapshotting supports them.
if git -C "$repo_root" ls-tree -r "$source_revision" | awk '$1 == "160000" { found = 1 } END { exit !found }'; then
  echo "Release blocked: submodule contents need an explicit release snapshot policy." >&2
  exit 1
fi
if [[ -n "$(git -C "$repo_root" status --porcelain --untracked-files=all)" ]]; then
  echo "Release blocked: tracked changes and untracked files must be committed or moved out of the checkout." >&2
  exit 1
fi
if [[ $# -gt 1 ]]; then
  source_directory=$2
  mkdir "$source_directory"
  git -C "$repo_root" archive --format=tar "$source_revision" | tar -xf - -C "$source_directory"
  if [[ ! -f "$source_directory/LICENSE" ]]; then
    echo "Release blocked: archive export rules omitted LICENSE." >&2
    exit 1
  fi
fi
printf '%s\n' "$source_revision"
