# AmazonDark v7.438 validation

- Exact v7.437 source parent: PASS.
- Search sponsored-results Objective-C literal: repaired by using CSS single quotes inside the attribute selector; exact repaired literal parses with clang Objective-C syntax check: PASS.
- `ADCheckoutTWBJS7369`: 8 `%.3f` conversions / 8 `factor` arguments: PASS.
- Dedicated `test_v7438_compile_fix.py`: PASS.
- v7.437 standalone-ad regression: PASS.
- v7.436 sponsored-search rail regression: PASS.
- v7.433 cross-frame probe regression: PASS.
- v7.432 SafeFrame regression: PASS.
- PDP completion/core regression: PASS.
- Checkout isolated-theme/native-payment/BYG regressions: PASS.
- Representative transition helper direct-parent tests: PASS.
- `sh -n scripts/ui-probe.sh`: PASS.
- `sh -n scripts/skeleton-probe.sh`: PASS.
- `scripts/lint-logos.sh`: PASS.
- Full Theos compile/link is not available in this container; GitHub Actions remains final compile/link proof.
