# TourKit snapshot

Source: https://github.com/rampatra/TourKit

Version: v1.0.0, commit `0cac3a51069e105286635601e82117c195058ee9`.

The library source and MIT license are retained locally so builds use reviewed code without fetching a moving dependency. The sample app, its assets and upstream test target are not bundled. Husk supplies its own artwork. No upstream artwork was copied.

Local changes:

- Optional button colors allow Husk's amber palette.
- Optional card background and fade can be disabled for an embedded, background-free tour. Text, controls and page indicators use semantic colors in both appearances.
- Reduce Motion disables slide and indicator animations. The system preference is the default; an optional override lets the fixture runner exercise both policies without changing host settings.
- Back and skip controls have spoken labels and hints; Left Arrow goes back. The hidden first-page back control is disabled and hidden from accessibility.
- Decorative artwork is hidden from accessibility and slide headings are marked as headers.

The embedded slideshow is used. The floating window controller remains upstream source and is not invoked by Husk. To update, compare against the pinned upstream source, reapply these small patches, review the diff, and rerun the onboarding interaction smoke checks.
