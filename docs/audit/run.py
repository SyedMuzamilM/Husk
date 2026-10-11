#!/usr/bin/env python3
"""Read-only audit probes for Husk. Compile into a temporary directory.

These record behavior, including known bugs; they are not a replacement for a
regression test target. No probe calls Trash on an existing path, signals a user
process, grants permissions, or changes app preferences. Run on macOS with Xcode.
"""

from pathlib import Path
import subprocess
import tempfile


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
APP = ROOT / "Husk" / "Husk"


def run(command, **options):
    return subprocess.run([str(arg) for arg in command], check=True, **options)


with tempfile.TemporaryDirectory(prefix="husk-audit-build-") as temporary:
    work = Path(temporary)
    # Expose two pure matching helpers without editing the app's access levels.
    matcher = (APP / "Services/AppUninstallService.swift").read_text()
    matcher = matcher.replace("actor AppUninstallService", "actor TestableAppUninstallService")
    matcher = matcher.replace("private func matchTokens", "func matchTokens")
    matcher = matcher.replace("private func matches", "func matches")
    (work / "Matcher.swift").write_text(matcher)
    sources = sorted((APP / "Models").glob("*.swift"))
    sources += [APP / "Theme/HuskTheme.swift"]
    sources += sorted((APP / "Services").glob("*.swift"))
    binary = work / "probes"
    run(["xcrun", "swiftc", "-swift-version", "5", "-parse-as-library", *sources,
         work / "Matcher.swift", HERE / "AuditProbes.swift", "-o", binary])
    run([binary], timeout=30)

    # Preserve the production task loop, replace only its metrics dependency.
    status = (APP / "Services/StatusViewModel.swift").read_text()
    status = status.replace("StatusViewModel", "TestableStatusViewModel")
    status = status.replace("SystemMetricsService", "StubSystemMetricsService")
    (work / "StatusModel.swift").write_text(status)
    lifetime = work / "lifetime"
    run(["xcrun", "swiftc", "-swift-version", "5", "-parse-as-library",
         APP / "Models/SystemMetrics.swift", work / "StatusModel.swift",
         HERE / "StatusLifetimeProbe.swift", "-o", lifetime])
    run([lifetime], timeout=10)

    # A metrics hang depends on host process count and command output size.
    measured = run(["/bin/ps", "-axo", "pid=,pcpu=,rss=,user=,comm="], capture_output=True)
    print("PS output bytes:", len(measured.stdout), flush=True)
    sample = subprocess.Popen([str(binary), "--metrics"], stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE)
    try:
        output, errors = sample.communicate(timeout=5)
        print(output.decode(errors="replace"), end="")
        print("Production metrics probe exit:", sample.returncode)
    except subprocess.TimeoutExpired:
        sample.kill()
        output, errors = sample.communicate(timeout=5)
        print(output.decode(errors="replace"), end="")
        print("Production metrics probe timed out; watchdog stopped fixture process")
