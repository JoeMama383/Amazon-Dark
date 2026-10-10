# AmazonDark v7.623 validation

## PASS

- Exact failing historical test `tests/test_v7597_live_thankyou.py`: the extracted Objective-C++ native helper compiles with clang++ gnu++98 stubs, and all v7.597 Live/thank-you paint contracts pass.
- New `tests/test_v7623_share_hook_compile_regression.py`: independently asserts hook placement and re-runs that full historical test. PASS.
- `tests/test_v7622_alexa_feedback_five_probes.py`: PASS. Retains all five shipped UI implementations.
- **30 of 30** normalized recent regression tests from v7.597 through v7.623: PASS, including v7.620, v7.621, v7.622, and v7.623.
- `bash scripts/lint-logos.sh`: PASS.
- `node --check src/ADNewMenus7622.js`: PASS.
- `bash -n` for UI/transition/performance probe scripts: PASS.
- Python compileall for src/tests: PASS.
- Package, probe, generated-include, helper-script and handoff version identity: PASS.
- All four checked existing UI modules unchanged in bytes from v7.622 source, including Alexa WebKit and Order/Shipping/Ad-privacy styling modules.

## Unverified

- The **complete** strict 281-regression serial suite was attempted, but did **not complete** in the local execution time limit. Do not interpret as 281/281 PASS. A separate normalized recent 30/30 set completed.
- A full Theos/iOS build was **not** performed here; the Apple SDK and Theos are not installed. GitHub Actions must establish compilation, and device installation/rendering must be checked on the iPhone.
- UIAppearance of system-hosted remote share sheet remains subject to iOS behavior.
