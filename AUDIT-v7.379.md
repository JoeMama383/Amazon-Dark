# AmazonDark v7.379 audit — teal transition forensics / Claude audit lock

## Baseline

- Direct parent: `7.378~byg-outline-one-shot-reload`.
- Parent `src/Tweak.xm` SHA-256: `9634b267097c3d18445b265efa3e8f4412e3f54bb88ac1212907aefd85f39c09`.
- Parent `src/AmazonDarkSB.xm` SHA-256: `f75490927eadb6461f7bfc7f095319a9f081166e6272e44e01fa684b506bc7ad`.

## Teal app-switcher state

The current evidence is not sufficient to justify another production visual mutation. Earlier paired screenshots/probes show an approximately RGB `(9,87,99)` / `(12,89,101)` teal surface in the switcher/warm handoff while the contemporaneous live Amazon `AppCXWindow` hierarchy is black. v7.376 removed the bad app-side snapshot cover and warm-splash suppression. v7.377 then removed the unscoped SpringBoard `_loadLiveXIBViewForApplication:` replacement, yet the user still reproduces teal.

The remaining diagnostic gap in v7.378 is temporal: `transition` stopped at `UIApplicationDidEnterBackground`, exactly when UIKit/SpringBoard takes over the saved scene and before the same-process warm return can be correlated. v7.379 changes the probe, not production pixels.

### App-side transition trace

- `transition` remains active for up to 120 seconds across background/foreground cycles.
- At each lifecycle notification it records the application state and a synchronous read-only census of up to 16 current `UIWindow`s: class/pointer/frame/window level/hidden/alpha, model + presentation background/opacity, root-controller class, and the same state for the top direct child.
- Display-link/native/WebKit recording remains opt-in and bounded.
- `launch` mode retains its old behavior and ends at the first background.

This specifically tests whether the teal plane exists for only a narrow lifecycle interval that a normal FULL screenshot or display-link sample can miss.

### SpringBoard placeholder trace

The generic `SBDeviceApplicationSceneViewPlaceholderContentViewProvider -_loadLiveXIBViewForApplication:` path is now observed only while `/var/mobile/AmazonDark-launch-probe.arm` is valid. The hook:

1. calls `%orig`;
2. reads at most 24 returned view nodes;
3. logs class, geometry, model/layer backgrounds, alpha, hidden state and child count;
4. returns the exact original object.

It does **not** call `ADLaunchArtwork7337`, create an image/view, recolor anything, add/remove subviews, or alter visibility. This is intentionally different from the rejected v7.337 production replacement.

### Production snapshot policy preserved

`XBApplicationSnapshot` remains the only SpringBoard image replacement path. `ADIsColdLaunchArtwork7337` still rejects protected content and `SceneContent` before any other launch provenance can authorize replacement. No app-switcher cover, saved-snapshot deletion, scene hierarchy mutation, warm-resume state machine, or new UIWindow is added.

## Claude audit closure

### ADTWBJS

Claude's confirmed issue is already fixed in the current lineage. The exact 14-argument mapping is:

`factor,factor,factor,factor,factor,shade,shade,shade,factor,factor,factor,shade,factor,factor`

The three Search/featured-video `rgba(0,0,0,alpha)` rules use `shade`; the other brightness-retention slots use `factor`. v7.379 locks this mapping in `test_v7379_claude_format_ci_audit.py`.

### ADStandalonePaintJS7104

The open mixed-precision audit is complete. There are exactly 12 float format positions:

`%.4f, %.4f, %.3f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.3f`

Their arguments are:

`factor,factor,shade,factor,factor,factor,factor,factor,factor,factor,factor,shade`

Both `%.3f` black-overlay alpha slots use `shade`; every `%.4f` brightness slot uses `factor`. No factor/shade bug exists in this function.

### CI/test-suite disconnect

Already repaired before v7.379 and now asserted by the same regression test:

- `.github/workflows/build.yml` uses `actions/setup-python@v5`.
- `AD_STRICT_VALIDATE=1 sh scripts/validate.sh` runs before Theos packaging.
- `scripts/validate.sh` always runs `scripts/lint-logos.sh`; strict/CI mode requires Python and runs every `tests/test_*.py`.
- The iPhone push path intentionally does not require Python.

## Acceptance / next diagnosis

One bad teal run should now tell us which owner is responsible without a cover:

- teal in `APP_LIFECYCLE.windows` before/background -> trace the exact Amazon window/top child owner;
- live windows remain black but `xib.observe` is teal -> generic SpringBoard placeholder/source is implicated, without v7.379 modifying it;
- both remain black while `snapshot.keep` shows `SceneContent` -> inspect the saved scene resource/delivery path rather than app theming;
- any `snapshot.dark` associated with the switcher interval -> re-audit launch-resource classification immediately.

No production teal correction should be claimed until this target-device trace identifies which of those paths actually rendered the pixels.
