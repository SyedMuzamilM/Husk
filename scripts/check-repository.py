#!/usr/bin/env python3
"""Check distribution notices and executable CI dependencies without network access.

Works in both a Git checkout and a committed source archive. This is not a
license classifier or a secret scanner.
"""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parent.parent
errors = []
for source, bundled in [
    ("LICENSE", "Husk/Husk/Husk-LICENSE.txt"),
    ("Vendor/TourKit/LICENSE", "Husk/Husk/TourKit-LICENSE.txt"),
]:
    original, resource = root / source, root / bundled
    if not original.is_file() or not resource.is_file():
        errors.append(f"Missing notice: {source} or {bundled}")
    elif not original.read_bytes().strip() or original.read_bytes() != resource.read_bytes():
        errors.append(f"Bundled notice differs from {source}: {bundled}")

for workflow in sorted((root / ".github/workflows").glob("*.y*ml")):
    for number, line in enumerate(workflow.read_text().splitlines(), 1):
        match = re.match(r"\s*(?:-\s*)?uses:\s*([^\s#]+)", line)
        if not match:
            continue
        reference = match[1].strip("\"'")
        if reference.startswith("./"):
            continue
        if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@[0-9a-f]{40}", reference):
            errors.append(f"{workflow.relative_to(root)}:{number}: Pin external actions to a full commit SHA")

if errors:
    for error in errors:
        print(error, file=sys.stderr)
    sys.exit(1)
print("Repository checks passed: bundled licenses match; external CI actions are pinned.")
