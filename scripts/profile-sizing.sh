#!/bin/bash
# Opt-in service benchmark. Creates and removes only its own temporary fixtures.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fixture_dir="$(mktemp -d /private/tmp/Husk-profile.XXXXXX)"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/husk-profile-build.XXXXXX")"
cleanup() {
  python3 - "$fixture_dir" "$build_dir" <<'PY'
import shutil,sys
for path in sys.argv[1:]: shutil.rmtree(path)
PY
}
trap cleanup EXIT
python3 - "$fixture_dir" <<'PY'
import os,sys
from pathlib import Path
count=int(os.environ.get('HUSK_PROFILE_ENTRIES','100000'))
if not 1 <= count <= 1000000: raise SystemExit('HUSK_PROFILE_ENTRIES must be between 1 and 1000000')
root=Path(sys.argv[1])
for index in range(count): (root / str(index)).touch()
PY
src="$repo_root/Husk/Husk"
swiftc -O -swift-version 6 -parse-as-library \
  "$src/Models/FileIdentity.swift" "$src/Models/RemovalPlan.swift" \
  "$src/Models/SafetyLabel.swift" "$src/Models/SizeMeasurement.swift" \
  "$src/Services/PathSafety.swift" "$src/Services/ScanPreferences.swift" \
  "$src/Services/CancelFlag.swift" "$src/Services/BlockingIO.swift" \
  "$src/Services/DirectorySizer.swift" "$src/Services/TrashService.swift" \
  "$src/Theme/HuskTheme.swift" "$repo_root/docs/performance/SizingMemoryProbe.swift" \
  -o "$build_dir/probe"
/usr/bin/time -l "$build_dir/probe" "$fixture_dir" > "$build_dir/result.txt" 2>&1
python3 - "$build_dir/result.txt" <<'PY'
import os,re,sys
from pathlib import Path
result=Path(sys.argv[1]).read_text()
rss=int(re.search(r'(\d+)\s+maximum resident set size',result).group(1))
footprint_match=re.search(r'(\d+)\s+peak memory footprint',result)
footprint=int(footprint_match.group(1)) if footprint_match else None
print(result.splitlines()[0])
print(f'Peak RSS: {rss/1048576:.2f} MiB')
print(f'Peak footprint: {footprint/1048576:.2f} MiB' if footprint is not None else 'Peak footprint: unavailable')
count=int(os.environ.get('HUSK_PROFILE_ENTRIES','100000'))
limit=int(os.environ.get('HUSK_PROFILE_RSS_LIMIT_MB','160'))
if count==100000:
 if 'visited=100000 status=complete' not in result: raise SystemExit('100K traversal did not complete')
 if rss > limit*1048576: raise SystemExit(f'100K service RSS exceeds {limit} MiB budget')
 print(f'100K service RSS budget passed: {limit} MiB')
PY
