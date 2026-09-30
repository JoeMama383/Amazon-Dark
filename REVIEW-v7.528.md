# AmazonDark v7.528 review

## Probe-backed target
The v7.526 FULL probe identifies the Interests plus control as:
- `li._bW9ia_plus-carousel-element_1z8GB`
- `._bW9ia_plus-container_1QjeQ._bW9ia_plus-thumbnail-link_2gUEq`
- actual 33x33 glyph owner `#create-prompt-link`

The probe shows the plus lane using black foreground/fill on the stock white control. v7.527 preserved the ring but did not explicitly own the plus glyph foreground.

## v7.528 change
- Keep the plus control floor OLED black.
- Keep its circular border gray (`#747a7c`).
- Force `#create-prompt-link`, its descendants, and its `::before` / `::after` paint white (`color`, text fill, fill, stroke).
- Retain all v7.527 Interests/product-grid theming unchanged.
- Preserve the existing-clone Git push workflow and separate FULL / VIEWPORT / TRANSITION handoff contract.

## Validation
- `scripts/lint-logos.sh`: PASS
- `bash -n scripts/ui-probe.sh`: PASS
- `bash -n scripts/skeleton-probe.sh`: PASS
- Current-version synchronization across package, tweak, probes, JS probe payloads and SB probe: PASS
- Normalized targeted regressions: PASS
  - `test_v7478_home_pdp_six_fix.py`
  - `test_v7480_build_syntax_guard.py`
  - `test_v7524_returns_thumbnail_render_geometry_revert.py`
  - `test_v7525_handoff_contract_repair.py`
  - `test_v7526_returns_thumbnail_taming_fix.py`
  - `test_v7527_interests_grid_oled_fix.py`
  - `test_v7528_interests_plus_white.py`
