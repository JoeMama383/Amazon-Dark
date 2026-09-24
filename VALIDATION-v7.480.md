# AmazonDark v7.480 validation

Package: `7.480~camera-permission-build-repair`

## Probe evidence

Camera VIEWPORT r2 identifies the full-screen permission renderer directly:

- `RCTView#fullscreen-inflight-animated-view` is the 430×932 white root.
- `fullscreen-inflight-permission-header`, the feature title/description, checkbox copy, and the neutral portion of the settings sentence are dark/gray React text.
- `fullscreen-inflight-prompt-dismiss-button` is the white 167×45.7 secondary pill.
- `fullscreen-inflight-prompt-allow-button` is the matching yellow primary pill.
- The 24×24 leaf below `allow-all-checkbox` is white with a 1 pt edge.
- `permission-icon-camera`, `fullscreen-feature-content-icon`, and `fullscreen-inflight-link-to-dashboard-icon` are SVG families. The same probe records saturated orange/teal paint that must remain authored.

## Camera implementation

- Full-screen permission root → OLED black.
- Neutral header/body text → light text; saturated attributed-string runs remain authored.
- `Not now` → established dark-gray secondary fill, white label, gray border.
- `Allow access` → OLED black, white label, gray border.
- New full-screen checkbox leaf → dark control fill + gray border.
- Historical `allow-all-CAMERA` checkbox ownership is deliberately preserved; v7.480 uses the separate `ADPermissionFullscreenCheckbox7480` owner instead of regressing the v7.409 behavior.
- Neutral SVG brushes → light; authored saturated orange/teal brushes remain unchanged.
- No MutationObserver, polling, RAF loop, recurring hierarchy scan, or web scroll listener is added. Permission hydration remains a bounded one-time pass.

## v7.479 build failure reproduced and repaired

The failing v7.479 package contains this malformed nested Objective-C message send in `ADPDPProbeBackedFixesJS7458`:

`return [NSString stringWithFormat:...] stringByAppendingString:ADReturnsThemeJS7480()];`

An isolated Clang Objective-C++ compile reproduces the failure as `missing '[' at start of message send expression`. v7.480 repairs the production expression to:

`return [[NSString stringWithFormat:...] stringByAppendingString:ADReturnsThemeJS7480()];`

The exact production Returns/PDP block now passes a GNU++98 Objective-C++ Clang syntax preflight. A new `test_v7480_build_syntax_guard.py` runs that exact preflight during `scripts/validate.sh`, so this specific class of v7.479 failure is rejected before the Theos build step in CI.

The external Returns JavaScript literal also passes C99 and GNU++98 syntax checks, the native Returns gradient helper passes an isolated Objective-C++ syntax check, and the exact new full-screen Camera checkbox/SVG helper functions pass an isolated Objective-C++ syntax check.

## Regression/static results

- **159/159 Python regressions passed** against the final v7.480 tree. The historical tests were run through the same v7.460→current identity normalization used by `scripts/validate.sh`; the new v7.480 build-syntax guard also passed.
- `lint-logos.sh`: PASS.
- `ui-probe.sh`, `skeleton-probe.sh`, and `validate.sh` shell syntax: PASS.
- FULL / VIEWPORT / TRANSITION source identities: synchronized to v7.480.
- `src/Tweak.xm`: **852,541 bytes**, below the 856,000-byte production gate.
- The monolithic `AD_STRICT_VALIDATE=1 sh scripts/validate.sh` invocation was also started and produced passing output until this environment terminated it on its execution-time limit; no failing assertion was encountered. The complete 159-test corpus was therefore verified in bounded sequential batches.

## Build boundary

This environment does not contain the Theos iOS SDK/toolchain used by the repository's final `make ... package` CI step, so a complete `.deb` compile cannot be truthfully claimed here. The source-level compiler failure that broke v7.479 was reproduced, repaired, and added to pre-build CI validation; the final package compile remains the GitHub Actions step after push.

## Executed preflight in this handoff

- `lint-logos.sh`: PASS.
- `scripts/ui-probe.sh`, `scripts/skeleton-probe.sh`, and `scripts/validate.sh`: shell syntax PASS.
- Latest ownership regressions (`v7.478` six-fix, `v7.479` timer/action-bar, Returns/email, Camera, and `v7.480` build-syntax guard): PASS.
- `ADReturnsTheme7480.js.inc`: C99 and GNU++98 literal-payload syntax PASS.
- Exact v7.479 malformed Objective-C++ expression independently reproduces Clang `missing '[' at start of message send expression`; the corrected v7.480 production block passes the Objective-C++ syntax guard.
- `src/Tweak.xm`: 852541 bytes, below the 856000-byte source gate.
- Package/Tweak/FULL/VIEWPORT/TRANSITION identities are synchronized at v7.480.
- The monolithic strict validator was also started and passed the startup/probe/sponsored/checkout regression sections reached before this container's execution window terminated it; the targeted current-version gates above completed independently.
