# AmazonDark v7.432 validation

- Exact source parent: v7.431 `pdp-r2-r5-fix`.
- Dedicated v7.432 SafeFrame regression: PASS.
- v7.431 PDP r2-r5 regression: PASS.
- PDP completion/core integration regression: PASS.
- Checkout core/hash isolation regressions: PASS after stripping the intentional new SafeFrame core member.
- BYG renderer regression: PASS.
- All 115 Python regression scripts: PASS. 109 completed in the parallel 10-second pass; the six intentionally slower probe/feature scripts were rerun individually and all passed.
- `scripts/lint-logos.sh`: PASS.
- `sh -n` for UI probe, skeleton/transition probe, and validation helper: PASS.
- New SafeFrame JavaScript emitted from Objective-C literals parses with `node --check`: PASS.
- No new MutationObserver, polling interval, RAF loop, web scroll listener, recurring hierarchy scan, or cross-origin parent DOM access.
- Full Theos compile/link is not available in this container; GitHub Actions remains compile proof.
- Device visual validation: pending v7.432 install.
