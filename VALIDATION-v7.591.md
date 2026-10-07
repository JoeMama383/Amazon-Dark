# AmazonDark v7.591 validation

Target: `7.591~regression-recovery-medical-search`

Validation was run against the final source revision after the last medical Shadow DOM/light-DOM ownership change.

## Final regression matrix

- normalized Python regressions: **244 / 244 PASS**
  - final batch 1: 82 / 82
  - final batch 2: 82 / 82
  - final batch 3: 80 / 80
- `scripts/lint-logos.sh`: PASS
- `scripts/ui-probe.sh` shell syntax: PASS
- `scripts/skeleton-probe.sh` shell syntax: PASS
- emitted `ADNewMenus7482.js.inc` JavaScript (`node --check`): PASS
- package / FULL / VIEWPORT / TRANSITION / launch identity synchronization: PASS

## Recovery-specific checks

- `ADUniversalUIProbe7362.inc` is behavior-identical to the known-good v7.585 implementation after normalizing only `7.585` -> `7.591`: PASS
- failed v7.590 foreground-hit-test arbitration (`ADUIForegroundOwnership7590`, `NATIVE_SCROLL_REJECT`, renderer-neutral rejection policy) absent: PASS
- PDP thumbnail TWB helper is additive-only and does not call `removeFromSuperlayer` / clear `kADTWBOverlay` for non-thumbnail images: PASS
- exact One Medical `glowModal` and `links-bottomsheet` Shadow DOM style injection present: PASS
- One Medical account-confirm `pui-section.content-container` light-DOM + bounded open-shadow ownership present: PASS
- pushed Your Orders search-results exact React search owner + Person palette promotion present: PASS
- v7.590 Shop the Show media/crop/tame ownership retained: PASS

## Regression policy correction

The v7.590 test that previously required the failed foreground-hit-test FULL arbitration was corrected. It now preserves the valid cumulative Shop the Show UI contract while asserting that the broken arbitration remains retired. The v7.591 regression independently locks the restored v7.585 FULL routing contract.
