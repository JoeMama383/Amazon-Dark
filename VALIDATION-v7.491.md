# AmazonDark v7.491 validation

## Scope

v7.491 is a focused follow-up on top of **v7.490** for the same Your Orders surface plus the already-fixed Book transition.

1. **Your Orders follow-up** (`section.your-orders-mobile-content-container.aok-relative.js-yo-container`)
   - Keeps the v7.490 OLED floors, white neutral headers, gray borders, white filter chevron, and tamed product/ad rasters.
   - Tames the **full blue reminder/info tiles** instead of only their small image wells.
   - Removes the extra **border work** from those blue tiles.
   - Forces the thick reminder-tile divider treatment to **OLED black**.
   - Collapses the search-bar **double-thick center seam** so the filter separator matches the surrounding 1 px line weight.
   - Re-themes the multi-item **quantity bubble** on purchase-history thumbnails to gray fill + gray border + white count.

2. **Book Details → See more transition**
   - The v7.490 `#a-white` OLED repaint remains unchanged and continues to be the production fix.
   - No new geometry, opacity, timing, hierarchy, or animation mutation is added.

## Validation completed

- `tests/test_v7491_your_orders_followup.py`: PASS.
- `tests/test_v7480_build_syntax_guard.py`: PASS.
- `scripts/lint-logos.sh`: PASS.
- `bash -n scripts/ui-probe.sh`: PASS.
- `bash -n scripts/skeleton-probe.sh`: PASS.
- `bash -n scripts/validate.sh`: PASS.
- `sh -n layout/DEBIAN/postinst`: PASS.
- Decoded `src/ADNewMenus7482.js.inc`: `node --check` PASS.
- Decoded `src/ADReturnsTheme7480.js.inc`: `node --check` PASS.
- Both JS include payloads still compile as adjacent literals under C99 and GNU++98: PASS.
- `src/Tweak.xm` remains below the repository 856,000-byte gate: PASS.

GitHub Actions remains the authoritative full Theos compile/link/package result.
