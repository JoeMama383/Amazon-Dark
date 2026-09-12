# AmazonDark v7.411 audit — permission first-paint owner fix

## Direct parent
v7.410~permission-text-location-firstpaint

## Why v7.410 failed despite its regression test
The v7.410 location fixture merged observations from different display ticks. The actual v7.409 transition trace shows:
- tick 733: full-width 430x18 neutral-white top rail first appears;
- tick 737: full-width clipping shell is still neutral white; an inset 394pt RCTView under RCTScrollContentView exists, but no RCTScrollView exists yet;
- tick 747: the concrete 394pt RCTScrollView finally mounts;
- tick 749: the clipping shell becomes black;
- tick 752: the top rail becomes black.
Therefore an owner gated on the concrete RCTScrollView cannot prevent the first visible white frames.

The permission-label path had the same class of dependency: exact button ancestry was already known, but the final white-text correction still waited for ADPermissionSheetKind7408. That allowed a stock-dark attributed-string rewrite to win when sheet classification lagged hydration.

## v7.411 correction
- Exact permission button text is owned from the probe-proven parent IDs (`actionButton`, `inflight-prompt-dismiss-button`, `inflight-prompt-allow-button`) before window/sheet classification.
- RCTTextView storage assignment and final draw both enforce white for those exact button descendants.
- RCTParagraphComponentView attributed-text assignment/layout uses the same exact button owner.
- AppCXWindow full-width neutral 8–24pt lower transition plates are painted OLED immediately, requiring no location route/root/scroller marker.
- The growing location clipping shell recognizes the early 394pt RCTView under RCTScrollContentView, roughly ten frames before the concrete RCTScrollView mounts.
- Existing orange selected-address edge, authored blue links, camera checkbox preservation, and single gray rounded React button border remain untouched.

## Performance
No MutationObserver, polling/interval loop, requestAnimationFrame loop, Web scroll listener, recurring hierarchy scan, delayed retry, new WKUserScript family, or timer was added. Ownership remains event-driven in existing React lifecycle/text/draw hooks.

## Validation
- 81/81 Python regression files: PASS (bounded parallel run), including exhaustive `test_probe_handoff.py`.
- `test_v7411_permission_firstpaint_owner_fix.py`: PASS.
- `test_v7411_skeleton_direct_parent_handoff.py`: PASS.
- `sh -n scripts/ui-probe.sh`: PASS.
- `sh -n scripts/skeleton-probe.sh`: PASS.
- `sh -n layout/DEBIAN/postinst`: PASS.
- `bash -n scripts/lint-logos.sh`: PASS.
- `bash scripts/lint-logos.sh`: PASS.
- Serial `AD_STRICT_VALIDATE=1 sh scripts/validate.sh` progressed through inherited tests with no assertion failure before the 120-second execution ceiling; the complete Python suite was run separately and passed 81/81.

## Build limitation
Theos is not installed/configured in this environment, so no local rootless `.deb` compile is claimed. Device/GitHub Actions packaging remains authoritative.
