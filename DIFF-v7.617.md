# AmazonDark v7.617 — CI probe handoff contract repair

Parent: **v7.616** complete source. This is a surgical CI/probe-helper contract fix. Existing UI colorization, raster taming, universal FULL/VIEWPORT implementation, and native Live changes are carried forward untouched.

## Root cause

GitHub's frozen regression `tests/test_v7392_probe_handoff_ci_fix.py` checks that `scripts/ui-probe.sh` contains `CUR=${VER#7.}`. v7.616 replaced that assignment with `CUR=${RUNTIME_VER#7.}` to find captures made by the installed tweak after a failed package build. The replacement preserved a useful runtime behavior but violated the established source handoff contract, causing strict CI to stop before compilation.

## Implementation

- `scripts/ui-probe.sh`: restores `CUR=${VER#7.}` at initialization, **then overrides CUR with the installed-version minor only when installed and helper versions differ**. `NAME=AmazonDark-v$RUNTIME_VER` stays unchanged. This satisfies the frozen handoff check while retaining v7.616's older-installed-build capture discovery.
- `scripts/validate.sh`: adds explicit invariants for both CUR expressions and protects the versioned source ZIP wildcard and separately labeled FULL, VIEWPORT, TRANSITION command headings.
- `tests/test_v7617_runtime_helper_handoff.py`: adds a concrete executable fake-installed-package fixture that verifies both current-v7.617 and older-installed-v7.615 FULL TAR exports, and validates shell syntax.
- `COMMANDS.md`: synchronizes v7.617 package/ZIP/stage identity, source wildcard, and labeled probe blocks; fixes additional frozen CI tests that inspect handoff docs.
- `src/ADNewMenus7482.js.inc`: synchronizes existing Prime loading/refinement and Shadow DOM section *comment markers* to v7.617 for frozen source-contract tests. No CSS declarations changed.
- Aligns package version, native and WebKit probe diagnostics, SpringBoard diagnostics, and three script helper version tags to v7.617.

## No behavior expansion

No newly introduced DOM observers, recurring scans, UI geometry, route-only probes, or image transformations. Current FULL/VIEWPORT/TRANSITION TAR export semantics retained.

## Verification limits

See `VALIDATION-v7.617.md`. The historical strict suite was started but exceeded this execution environment's limit. The exact previously failing frozen test and newer tests passed individually; a fresh GitHub Actions strict run and Theos package compilation are required to certify the full build.
