# AmazonDark v7.616 — validation

**Completed PASS:**

- `python tests/test_v7616_universal_probe_transport.py` — runs local fake-Amazon-container fixtures for installed-v7.615/helper-v7.616 and installed-v7.616/helper-v7.616; verifies real TAR manifest and content, metadata-free state discovery, old-version exclusion, one-time foreground FULL arm, screenshot receipt wiring, CI diagnostics.
- `bash scripts/lint-logos.sh` — PASS.
- `sh -n scripts/ui-probe.sh`, `sh -n scripts/skeleton-probe.sh`, `sh -n scripts/performance-probe.sh` — PASS.
- `python -m compileall -q tests src` — PASS.
- Exact package, helper, FULL/VIEWPORT/TRANSITION/native/SpringBoard versions synchronized to v7.616.

**Strict historical regression status: INCOMPLETE, not a PASS.**

`AD_STRICT_VALIDATE=1 sh scripts/validate.sh` progressed without reported assertion failures through the v7.386 tests before the local command execution timed out and terminated. The captured console log is included. It did not complete the ~273-test suite. The GitHub Actions strict validation job must finish to certify the full historical suite.

**iOS compilation and real-device scan: UNVERIFIED.**

The local environment has no Theos/iOS SDK. The prior user-shared CI log omitted the two actual compiler `error:` lines, so this update cannot establish their root cause. The CI workflow has been updated to print and archive the real errors. No claim is made that v7.616 builds or that FULL now traverses every Amazon menu on-device. The change fixes a concrete helper/runtime version mismatch and provides a screenshot-independent, same-walker FULL foreground fallback, both of which still require installation and field testing.
