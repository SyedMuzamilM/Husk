# Source and asset inventory

This inventory is preparation for publication, not legal clearance.

| Material | Current source | Publication action |
|---|---|---|
| Swift application and tests | Local repository history and current implementation work | Owner must confirm ownership of earlier code and acceptable contribution terms. TourKit is listed separately below. |
| TourKit onboarding | Local v1.0.0 snapshot, upstream commit `0cac3a51069e105286635601e82117c195058ee9`, under Vendor/TourKit | MIT notice preserved in Vendor/TourKit/LICENSE and bundled as TourKit-LICENSE.txt. Local accessibility, motion and button-color patches are documented beside the source. No sample-app code or artwork is bundled. |
| Tour illustrations | scripts/generate-tour-artwork.swift using the existing Husk logo and system symbols | Reproducible original composition; inherits existing logo and Apple-symbol rights requirements. No upstream TourKit images were copied. |
| App icon and Husk brand images | Existing Assets.xcassets and root husk-logo.png | Confirm creation source and commercial/reuse rights. Duplicate unassigned icon variants were removed; assigned assets remain. |
| stitch_husk_macos_interface_design | Existing design reference/export directory | Confirm export terms and rights to all images/fonts before including it publicly. It is not a Swift package dependency. |
| Product/research documents | Local docs and cited official sources | Review quotations and old market/pricing claims. Planning documents now identify themselves as proposals. |
| Mole comparison | Official Mole web pages/repositories cited in the competitor audit | Independent behavior analysis only. No Mole implementation or assets were imported. GPLv3 CLI and proprietary GUI terms differ. |
| CI action | actions/checkout pinned to v4.2.2 commit | Used in CI, not bundled into the application. Review action updates by commit. |
| Apple APIs and SF Symbols | System frameworks and platform symbols | Follow Apple platform/tooling terms; no third-party font is bundled by this implementation. |

A limited Git-history scan examined 367 unique objects on 2026-10-11 for high-confidence private-key, AWS access-key, GitHub-token, and OpenAI-style token patterns. It found no matching file paths. This is not exhaustive secret detection and does not prove that credentials never entered history. CI/release credentials are not present in this checkout.

Do not add LICENSE until the actual owner approves the license and copyright attribution. Do not assume a design reference or generated logo has automatically cleared rights. Private vulnerability reporting, moderation contact, and contribution terms still need owner setup.
