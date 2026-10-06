# AmazonDark v7.578 validation

Package: `7.578~capture-regression-restore`
AD_VERSION: `v7.578-capture-regression-restore`

## Root cause repaired

v7.577 was validated against an incomplete source archive: `tests/test_v7574_capture_ui_completion.py` still existed in the GitHub clone but was absent from the handoff ZIP. Because the established push workflow overlays the ZIP onto the existing clone, GitHub Actions retained and executed that regression. v7.578 restores that regression source into the handoff and restores the production contract it protects.

## Restored capture contract

- PDP `dpx-reviews-pill`: medium-gray fill, standard gray border, white text.
- Lower video ad Sponsored pill: 90% black container only; Sponsored copy/info glyph/video semantic paint untouched.
- Video-ad product-image floor keeps normal blending.
- Video-ad description and Other Sellers price text are white.
- PCPO category slot is OLED.
- Captured media leaves (video-ad thumbnail, Keepa/Camel charts, Customers-also-bought, FBT, PCPO category art, Prime Deals banner) use the preference-controlled brightness leaf rule and survive legacy visibility-reset delivery order.
- No MutationObserver, setInterval, or requestAnimationFrame introduced.
- The inherited performance invariant remains exactly one `querySelectorAll(` in `Tweak.xm`.

## Full regression result

Command: `AD_STRICT_VALIDATE=1 sh scripts/validate.sh`
Result: **PASS / exit code 0**
Source regressions: **231/231 PASS**
Final line: `python-regressions: OK (231)`

This run was performed after the v7.578 package/probe/version bump, not on the pre-bump source tree.
