# AmazonDark v7.622 — Validation

- PASS: focused `test_v7622_alexa_feedback_five_probes.py` native/WebKit scope contract.
- PASS: historical recent tests for v7.618, v7.619, v7.620, v7.621 normalized to the v7.622 release identity (6/6, including v7.622).
- PASS: `bash scripts/lint-logos.sh`.
- PASS: `node --check src/ADNewMenus7622.js`.
- PASS: `clang++ -std=gnu++98 -fsyntax-only` on actual v7.622 JS include wrapper.
- PASS: probe shell helpers' bash syntax.
- LIMITATION: a complete `AD_STRICT_VALIDATE=1 sh scripts/validate.sh` was attempted, but terminated at the execution limit after 43 PASS lines; it is NOT claimed as a full-suite pass.
- LIMITATION: Apple UIKit SDK and Theos build system are unavailable locally, so native iPhone compilation / device UI paint is not verified.
- LIMITATION: ad feedback nested frame and remote iOS ShareSheetUI require real on-device validation; no verified external paint is claimed.
