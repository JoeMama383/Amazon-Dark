# AmazonDark v7.450 validation — PDP read-only FULL

Direct parent: `v7.449~full-probe-nonblocking` (`AmazonDark-v7.449-full-probe-nonblocking-source.zip`, SHA-256 `6ca3e5366c9a63f590c201eb480f1ecb0d9db88e1ec928514b5f27058eae4887`).

## Final-source validation

- `bash scripts/lint-logos.sh`: PASS.
- `sh -n scripts/ui-probe.sh`: PASS.
- `sh -n scripts/skeleton-probe.sh`: PASS.
- `sh -n layout/DEBIAN/postinst`: PASS.
- All **128/128** `tests/test_*.py` regression files: PASS on the final source in deterministic chunks.
- `tests/test_v7448_performance_consolidation.py`: PASS; production source-size and recurring-work gates preserved. The probe-only include ceiling is 76 KB and the final file is below it.
- `tests/test_v7449_full_probe_nonblocking.py`: PASS; inherited non-PDP cooperative FULL remains present.
- `tests/test_v7450_pdp_readonly_full.py`: PASS; product classification, read-only Web collection, PDP-session preflight, native-scroll bypass, and non-PDP routing are locked.
- `git diff --no-index --check` against the exact v7.449 source: PASS (no whitespace diagnostics).

A monolithic `AD_STRICT_VALIDATE=1 sh scripts/validate.sh` run advanced through the production/cold-launch/UI contracts without a failure before the execution environment's 45-second command cap stopped it. The complete Python regression suite was therefore run separately in bounded chunks; every test passed.

## Parent-diff boundary

- `src/Tweak.xm`: production code differs only in release comment/version identity.
- `src/ADSponsored.m`: byte-identical to v7.449.
- `src/AmazonDarkSB.xm`: launch-probe filename identity only.
- Functional runtime delta is confined to the explicitly triggered universal probe implementation plus regenerated probe/helper identities/tests/docs.

## PDP no-mutation contract

- Product routes are detected from native `WKWebView.URL.path` before any FULL Web scan: `/dp/`, `/gp/product/`, `/gp/aw/d/`.
- Exact DOM root `#dp` remains a bounded fallback classifier.
- PDP detection is completed before any FULL WebView is scanned.
- Once PDP is present, all WebViews in that FULL capture use read-only cooperative mounted-DOM inventory + passive catch-up.
- The PDP read-only block contains no `setContentOffset:`, `scrollEnabled=`, JavaScript scroll command, `scrollTo`, or nested-owner drive.
- The generic native scroll discovery/sweep phase is skipped for the entire PDP FULL session.
- Initial/final native hierarchy snapshots remain read-only.

## Runtime architecture

No production `MutationObserver`, Web scroll listener, `setInterval`, RAF loop, polling loop, or recurring hierarchy scan is introduced.

## Build/device boundary

Theos/iOS SDK packaging is not available in this container. GitHub Actions remains the arm64/arm64e compile/link/package authority, and the installed phone build remains the only proof that the product interface no longer freezes on capture.
