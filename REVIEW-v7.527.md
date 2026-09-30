# AmazonDark v7.527 review

## Scope
Probe-backed fix for the Interests / product-grid menu captured in `AmazonDark-v7.526-ui-full-probe-20260930-080434-582-r1.tar`.

## What changed
- Added an exact `#a-page:has(#interests-ai-sticky-div):has(#product-grid)` owner block in `src/ADNewMenus7482.js.inc`.
- Forces OLED floors for:
  - the Interests sticky header family
  - interest chip/header surfaces
  - product cards / product-grid neutral surfaces
  - Amazon's Choice header family
  - the heart row family
- Forces white neutral text for the sticky header and product-grid neutral copy.
- Forces heart glyphs white and keeps the row behind them OLED.
- Converts Add to cart buttons to OLED with gray borders and white text.
- Tames Interests header images.
- Preserves the active interest chip blue ring and keeps the plus toggle on the gray-ring contract.
- Bumped version/handoff assets to `v7.527`.
- Added manual regression test `test_v7527_interests_grid_oled_fix.py`.

## Validation performed
- `python .ad-regressions.manual/test_v7527_interests_grid_oled_fix.py` ✅
- `python tests/test_v7480_build_syntax_guard.py` ✅
- `AD_STRICT_VALIDATE=1 sh scripts/validate.sh` progressed through the standard suite and passed the new version-sync / transition-helper gates in this environment before the long-running run was terminated by the container timeout.
