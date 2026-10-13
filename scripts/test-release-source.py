#!/usr/bin/env python3
"""Exercise the real release entry point in disposable Git repositories.

Verification is replaced by a fixture that records its working directory and
exits before building, signing, or contacting Apple's notarization service.
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPTS = Path(__file__).resolve().parent


class ReleaseSourceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="husk-release-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo = self.root / "repository with spaces"
        self.repo.mkdir()
        self.git("init", "--quiet")
        (self.repo / "scripts").mkdir()
        for name in ["release.sh", "prepare-release-source.sh"]:
            if (SCRIPTS / name).exists():
                shutil.copy2(SCRIPTS / name, self.repo / "scripts" / name)
        verify = self.repo / "scripts/verify.sh"
        verify.write_text('#!/bin/bash\npwd > "$HUSK_TEST_MARKER"\nexit 91\n')
        verify.chmod(0o755)
        (self.repo / "LICENSE").write_text("Disposable license fixture\n")
        (self.repo / ".gitignore").write_text("ignored.swift\n")
        (self.repo / "Husk").mkdir()
        (self.repo / "Husk/tracked.swift").write_text("// committed fixture\n")
        self.commit()
        self.marker = self.root / "verification-started"

    def git(self, *args):
        environment = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
        return subprocess.run(
            ["git", "-C", str(self.repo), "-c", "core.hooksPath=/dev/null",
             "-c", "commit.gpgSign=false", "-c", "user.name=Fixture",
             "-c", "user.email=fixture@example.invalid", *args],
            env=environment, check=True, capture_output=True, text=True).stdout.strip()

    def commit(self):
        self.git("add", ".")
        self.git("commit", "--quiet", "-m", "Release fixture")

    def release(self):
        environment = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
        environment.update(HUSK_SIGNING_IDENTITY="fixture", HUSK_TEAM_ID="fixture",
                           HUSK_NOTARY_PROFILE="fixture", HUSK_TEST_MARKER=str(self.marker),
                           HUSK_TEST_REPO=str(self.repo), TMPDIR=str(self.root))
        return subprocess.run(["bash", str(self.repo / "scripts/release.sh")],
                              env=environment, capture_output=True, text=True)

    def test_untracked_source_never_starts_verification(self):
        (self.repo / "Husk/untracked.swift").write_text("// uncommitted fixture\n")
        result = self.release()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.marker.exists(), "Release started building untracked source")

    def test_tracked_or_staged_changes_never_start_verification(self):
        for staged in [False, True]:
            with self.subTest(staged=staged):
                (self.repo / "Husk/tracked.swift").write_text("// modified fixture\n")
                if staged:
                    self.git("add", "Husk/tracked.swift")
                result = self.release()
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.marker.exists())

    def test_verification_uses_committed_snapshot_and_omits_ignored_source(self):
        (self.repo / "Husk/ignored.swift").write_text("// local source must not ship\n")
        result = self.release()
        self.assertEqual(result.returncode, 91, result.stderr)
        snapshot = Path(self.marker.read_text().strip())
        self.assertNotEqual(snapshot, self.repo)
        self.assertEqual((snapshot / "Husk/tracked.swift").read_text(), "// committed fixture\n")
        self.assertFalse((snapshot / "Husk/ignored.swift").exists())
        self.assertFalse((snapshot / ".git").exists())

    def test_snapshot_contains_committed_vendor_and_license(self):
        vendor = self.repo / "Vendor/TourKit"
        vendor.mkdir(parents=True)
        (vendor / "LICENSE").write_text("Vendor license fixture\n")
        self.commit()
        result = self.release()
        self.assertEqual(result.returncode, 91, result.stderr)
        snapshot = Path(self.marker.read_text().strip())
        self.assertEqual((snapshot / "LICENSE").read_text(), "Disposable license fixture\n")
        self.assertEqual((snapshot / "Vendor/TourKit/LICENSE").read_text(), "Vendor license fixture\n")

    def test_missing_committed_license_never_starts_verification(self):
        self.git("rm", "LICENSE")
        self.git("commit", "--quiet", "-m", "Fixture without license")
        result = self.release()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.marker.exists())
        self.assertIn("LICENSE", result.stderr)

    def test_source_changes_during_verification_stop_before_signing(self):
        verify = self.repo / "scripts/verify.sh"
        verify.write_text('#!/bin/bash\nprintf modified > "$HUSK_TEST_REPO/Husk/tracked.swift"\n')
        self.commit()
        result = self.release()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("tracked changes", result.stderr)

    def test_export_rules_cannot_omit_project_license(self):
        (self.repo / ".gitattributes").write_text("LICENSE export-ignore\n")
        self.commit()
        result = self.release()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.marker.exists())
        self.assertIn("archive export rules omitted LICENSE", result.stderr)

    def test_gitlinks_are_rejected_instead_of_archived_without_contents(self):
        revision = self.git("rev-parse", "HEAD")
        self.git("update-index", "--add", "--cacheinfo", f"160000,{revision},Vendor/Pinned")
        self.git("commit", "--quiet", "-m", "Fixture with gitlink")
        result = self.release()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.marker.exists())
        self.assertIn("submodule contents", result.stderr)


if __name__ == "__main__":
    unittest.main()
