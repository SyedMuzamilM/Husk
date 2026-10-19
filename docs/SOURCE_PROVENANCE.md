# Source and asset inventory

The owner selected the Husk Source-Available License on 2026-10-19, replacing MIT for the current offering. The earlier MIT grant and approval of original brand assets on 2026-10-13 remain recorded in [NOTICE.md](../NOTICE.md). [LICENSE](../LICENSE) contains the current terms; the [licensing guide](LICENSING.md) explains the transition. This inventory records provenance, not independent legal certification.

| Material | Source and treatment |
|---|---|
| Swift app, fixtures, scripts, and original docs | Repository history and contributor work; Husk Source-Available License for the current offering. Prior MIT rights remain intact. New contributions follow CONTRIBUTING.md; contributors retain copyright and permit the maintainer to distribute their contributions under the project terms. |
| TourKit | Vendored MIT v1.0.0 at commit `0cac3a51069e105286635601e82117c195058ee9`. Complete upstream notice remains in Vendor/TourKit/LICENSE and the app's TourKit-LICENSE.txt. Local patches are listed in Vendor/TourKit/README.md. No sample-app artwork is bundled. |
| Husk logo and app icon | Existing Assets.xcassets and root husk-logo.png. Owner confirmed distribution rights. Current original artwork is offered under the Husk Source-Available License, without revoking earlier MIT grants. |
| Tour illustrations | Reproducible composition from scripts/generate-tour-artwork.swift using Husk artwork and system symbols. Apple's symbol rights remain subject to Apple's terms. |
| Documentation | Original implementation and policy writing with cited primary sources. Obsolete plans and prototype exports were removed from the current tree; earlier versions remain in Git history. |
| Mole research | Independent behavior analysis with pinned source links in the AI storage guide. No Mole code or assets were imported. GPL code cannot be accepted under Husk's restricted distribution terms without a separate compatible grant from its rightsholders. |
| CI actions | Commit-pinned actions/checkout, used by CI and not bundled. Dependabot proposes action updates for review. |
| Apple APIs and SF Symbols | System frameworks and platform symbols under Apple's terms. No third-party font is bundled in the native app. |

The app bundles matching copies of the root Husk license and TourKit's MIT notice. `scripts/check-repository.py` verifies them before builds, including from source archives. The historical Husk MIT notice is retained in docs/licenses/Husk-MIT-legacy.txt.

A limited history scan on 2026-10-11 examined 367 unique objects for high-confidence private-key, AWS-key, GitHub-token, and OpenAI-style token patterns without a match. The 2026-10-13 scan checked 355 historical blobs and 207 current files with zero matches; see the current verification record. Pattern matching is not exhaustive and does not prove credentials never entered history. Enable GitHub secret scanning and push protection when repository settings permit it. Never commit signing keys, notary credentials, or private diagnostic data.

Private security and conduct reports go to muzamil@mzml.dev. The repository owner controls publication and GitHub security settings. No publication or advisory-setting change is implied by the local license commit.
