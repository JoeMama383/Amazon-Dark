# AmazonDark v7.480 — Camera permission + build repair

Direct parent: the regenerated v7.479 source containing the TNF/PDP fixes and Return Instructions / Email-copy theming.

v7.480 preserves those repairs, themes the probe-backed full-screen Camera permission family captured in VIEWPORT r2, and repairs the Objective-C++ syntax error that caused the v7.479 package build to fail.

## Camera permission screen

The probe identifies `RCTView#fullscreen-inflight-animated-view` as the full-screen white root. v7.480 makes that root OLED black and converts only neutral React text/brushes to light colors. Saturated semantic paint remains authored, including the orange camera accent and teal permission-settings link.

The exact actions are `fullscreen-inflight-prompt-dismiss-button` and `fullscreen-inflight-prompt-allow-button`. `Not now` uses the established secondary dark-gray fill; `Allow access` uses OLED black. Both use white labels and the standard gray edge while retaining the native 24 pt pill geometry.

The new 24×24 checkbox leaf under `allow-all-checkbox` receives the dark control fill and gray edge through a new exact owner, `ADPermissionFullscreenCheckbox7480`. The older `allow-all-CAMERA` checkbox remains on its historical preservation path, preventing the new screen from regressing the older permission renderer.

No MutationObserver, polling, RAF loop, recurring hierarchy scan, or web scroll listener is added.

## v7.479 build repair

The failing v7.479 source chained `stringByAppendingString:` onto `[NSString stringWithFormat:...]` without an outer `[` in `ADPDPProbeBackedFixesJS7458`. Clang reproduces the failure as a missing message-send bracket. v7.480 uses the valid nested form and adds a regression that compiles the exact production Returns/PDP block with Clang before the CI Theos build.

## Preserved repairs

The TNF countdown paint, PDP action-bar edge removal, Return Instructions and Email-copy themes, authored blue return-deadline ring, semantic link colors, and native bottom-gradient suppression remain intact.
