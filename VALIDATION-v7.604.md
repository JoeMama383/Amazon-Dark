# AmazonDark v7.604 — validation

Source parent: v7.603. Target evidence: four v7.602 independent VIEWPORT captures supplied in Archive(20261009-152706).zip.

## Results

- **PASS: 261/261 source-level Python regressions**, using the current `scripts/validate.sh` identity normalization and running the resulting tests in four isolated workers. Detailed per-test results are in the separately linked `AmazonDark-v7.604-validation.log`.
- **PASS: `bash scripts/lint-logos.sh`**.
- **PASS: `tests/test_v7604_pdp_viewport_finish.py`**, including literal probe-owner CSS selector coverage, no geometry/recurring scans, Node JavaScript parse, gnu++98 include compilation.
- **PASS: inherited v7.600, v7.601, v7.602, and v7.603 targeted regressions**.
- **NOT RUN: complete iOS Theos package build or on-device visual inspection**, because this environment does not have the iPhone or the iOS Theos toolchain. The user's installation and follow-up probes must verify final paint.

## Captured owners and evidence

- r1, scrollY=5151: Similar products `#sims-substitutes_feature_div_0`, 32×32 white `_cDEzb_mltIngressIcon_` floor at x=173/373 y=213 (and next row), `span.a-price.aok-align-center` stock #0f1111 on OLED.
- r2, scrollY=7192: played inline `<video>` inside `_single-video-ads-card_style_clickThrough__`, sponsored badge rgba(0,0,0,.9), price row `_single-video-ads-card_style_priceRow__`.
- r3/r4, scrollY=2122/2702: `#topHighlights > hr.hoc-divider` authored 1px top rule; dark `i.a-icon-extender-expand` in `#hoc-topHighlights-expander`. Borders are recolored, not redrawn.

No new DOM walkers, mutation observers, repeated timers, geometry adjustments, route dispatchers, or probe format changes.
