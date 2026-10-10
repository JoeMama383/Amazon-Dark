# AmazonDark v7.617 — Validation record

## Exact reported failure: FIXED and verified

The v7.616 strict CI failure was:

```
assert 'VER=7.616' in U and 'CUR=${VER#7.}' in U
AssertionError
```

`CUR=${VER#7.}` is restored in `scripts/ui-probe.sh` while installed-version runtime overrides are retained. The normalized v7.617 copy of `test_v7392_probe_handoff_ci_fix.py` ran successfully. The normalized `test_v7616_universal_probe_transport.py` and new `test_v7617_runtime_helper_handoff.py` both passed, including real TAR fixture exports for current and older installed versions.

## Other targeted source regression results

PASS: `test_v7614_probe_version_and_strict_ci.py` (version/handoff/three helpers)
PASS: `test_v7542_keyboard_consumer_probe.py`
PASS: `test_v7544_keyboard_private_state_probe.py`
PASS: `test_v7582_prime_transition_loading_paint.py`
PASS: `test_v7583_prime_refinement_divider_recolor.py`
PASS: `test_v7591_regression_recovery_medical_search.py`
PASS: v7.592–v7.604 targeted late regressions
PASS: v7.605–v7.617 targeted late regressions
PASS: `sh -n scripts/ui-probe.sh` and `sh -n scripts/validate.sh`

Several previously failing historical tests were caused by outdated **handoff document source wildcard** or **comment marker** identities, not runtime changes; the corresponding artifacts were synchronized and the tests rerun successfully.

## Important limitations

- `AD_STRICT_VALIDATE=1 sh scripts/validate.sh` was attempted on the v7.617 source but timed out during the long historical serial test run. It is **not** represented as a complete suite PASS.
- A full independent Theos/Apple SDK Objective-C++ build cannot be run here. GitHub CI has to confirm native compiler success after strict validation.
- Real iPhone screenshot-to-FULL traversal on all routes has **not** been certified; this build fixes the source/transport regression, not every outstanding menu-renderer issue.
- Remote `git push` is user-executed from the existing clone; it has not been performed by this assistant.
