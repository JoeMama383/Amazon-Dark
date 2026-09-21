# AmazonDark v7.440 validation

## Source identity

- Package: `7.440~pdp-frame-ownership`
- Source identity: `v7.440-pdp-frame-ownership`
- FULL / VIEWPORT universal probe identity: `7.440`
- TRANSITION probe identity: `7.440`
- Parent: exact v7.439 release archive tree

## Regression inventory

All 122 `tests/test_*.py` production regressions passed on the v7.440 source tree.

The environment execution window is shorter than the sequential `scripts/validate.sh` runtime, so the complete inventory was executed in a bounded pass and the remaining long-running tests were completed separately. Result: **122 passed, 0 failed**.

High-value release regressions explicitly rerun after the frame-ownership change:

- `test_probe_handoff.py` — PASS
- `test_v7433_universal_crossframe_probe.py` — PASS
- `test_v7436_search_sponsored_rails_fix.py` — PASS
- `test_v7438_compile_fix.py` — PASS
- `test_v7439_pdp_ui_completion.py` — PASS
- `test_v7440_pdp_frame_ownership.py` — PASS

## Static/release checks

- `scripts/lint-logos.sh` — PASS
- `sh -n scripts/validate.sh` — PASS
- `sh -n scripts/ui-probe.sh` — PASS
- `sh -n scripts/skeleton-probe.sh` — PASS
- `layout/DEBIAN/postinst` mode — 755
- No new MutationObserver, interval/polling loop, RAF loop, web scroll listener, or recurring hierarchy scan in the v7.440 frame-owner path.

## WebKit API sanity check

The delivery mechanism matches WebKit's published/private Cocoa API shape used by iOS 17:

- `WKWebView -_frames:` returns a `_WKFrameTreeNode *`.
- `_WKFrameTreeNode` exposes `info` and `childFrames`; `info` is available on iOS 17.
- `WKWebView -evaluateJavaScript:inFrame:inContentWorld:completionHandler:` is available from iOS 14 and targets the specified `WKFrameInfo`.

## Build limitation

Theos/iOS SDK are not installed in this container, so the actual arm64/arm64e tweak compile remains GitHub CI's responsibility. The source-side compiler regression that caught the v7.437 Objective-C quoting failure remains passing.

## Device status

Pending v7.440 CI build/install and live verification of the affected PDP ad families. Do not classify the ad UI as device-fixed until that check passes.
