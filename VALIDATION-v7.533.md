# VALIDATION v7.533

Release: `7.533~web-theme-parse-regression-repair`

## Root cause

The light-mode regression in v7.530-v7.532 was caused by a malformed JavaScript escape in `src/ADNewMenus7482.js.inc`. The replacement three-dot glyph was encoded as CSS `content:'\\22EE'` inside a JavaScript template literal. After C/JSON string reconstruction the WebKit user script contained `content:'\22EE'`, which JavaScript rejects at parse time. Because `ADNewMenusJS7482()` is appended to the main WebKit theme payload, that one parse failure prevented the entire web theme script from executing, producing stock white Home/Interests surfaces.

v7.533 changes the glyph to the literal `⋮`, preserving the intended CSS while making the reconstructed JavaScript valid.

## Regression hardening

- Updated the v7.529 Interests overflow regression so it protects the visual contract without requiring the malformed escape.
- Added `test_v7533_web_theme_payload_parse.py`, which reconstructs the actual shipped `ADNewMenus7482.js.inc` bytes and runs `node --check` on them.
- Added `test_v7533_interests_visual_contract.py` covering the contextual menu, plus, product text/price, filled heart, rating, bottom sheet and frozen handoff contract.

## Complete normalized source regression run

The same normalization logic used by `scripts/validate.sh` was applied to the final v7.533 source tree. All **189/189** `tests/test_*.py` regressions were executed in bounded groups and passed, including every historical test from startup/cold-launch through v7.533 and the exact v7.529 regression that exposed the prior failure.

Additional preflight:
- `scripts/lint-logos.sh`: PASS
- `sh -n scripts/ui-probe.sh`: PASS
- `sh -n scripts/skeleton-probe.sh`: PASS
- reconstructed `ADNewMenus7482.js.inc` `node --check`: PASS
- `test_v7480_build_syntax_guard.py`: PASS
- `test_v7448_performance_consolidation.py`: PASS
- `test_v7507_probe_identity_sync.py`: PASS
- source/package/probe version synchronization: PASS
