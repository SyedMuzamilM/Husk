# Privacy

The current app performs no network requests and sends no telemetry. TourKit onboarding loads only bundled artwork and text; its reviewed local source has no network client or analytics. It reads filesystem metadata and process names locally. Sizing does not read regular-file contents or download cloud-only files. Bundle metadata and app-owned history JSON are read for their respective features.

Optional operation history stores original paths, Trash destinations, timestamps, and errors at `~/Library/Application Support/Husk/operations.json`. Its directory uses owner-only permissions and the file uses mode 0600. History retains at most 100 records for 30 days; expired records are pruned when read or written. Disable or clear it in Settings. The app does not upload it. Same-user software can still access it.

Exclusions, project inspection roots, appearance, and onboarding settings are stored in UserDefaults. No credentials belong in these settings. Full Disk Access is optional; the permission indicator is a heuristic. Actual coverage is reported by measurements.

Sharing logs/screenshots or GitHub reports can disclose user names, file paths, app names, and process names. Redact them first. A future update checker, crash reporter, or network feature needs a policy update and a separate implementation review.
