# Contributing

License selection and source/asset provenance are pending. Confirm contribution terms with the owner before accepting external contributions. No CLA or DCO policy has been adopted yet.

Use Xcode 26.2+ and macOS 14+. Follow README build steps and run `scripts/verify.sh`. Keep Swift 6 checking enabled. Do not add dependencies without explaining why native APIs are insufficient.

Changes to deletion, ownership, sizing, cancellation, process supervision, or resource lifetime need regression fixtures at the real service boundary. Tests must use disposable paths and injected Trash operations. Never run a cleaner against a contributor's actual home directory as a test.

Each new cleanup rule needs exact path evidence, supported app/tool versions, owner association, what can be lost, how data is regenerated, active-use behavior, protected/excluded/symlink fixtures, and measurement coverage. Unknown data starts as Review or inspection-only. See docs/RULES.md.

Keep commits focused. Include the problem, resulting behavior, validation, and remaining limits in the PR. Do not commit personal signing teams, keys, tokens, generated build products, private path logs, or user screenshots.

For UI changes, check system/light/dark appearance, keyboard navigation, VoiceOver, Reduce Motion, resized windows, and the exact review/result path. Avoid icon-only destructive actions and nested buttons.

For security defects follow SECURITY.md. For normal bugs use the issue template with redacted fixture steps. Be respectful, discuss behavior and evidence, and avoid personal attacks or sharing another person's private information. Moderation and private conduct contact still need owner configuration before community launch.
