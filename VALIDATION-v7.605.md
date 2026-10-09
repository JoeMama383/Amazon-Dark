# AmazonDark v7.605 — validation

Parent source: v7.604. Visual target: user's 12:08 screenshot of Reduced carbon impact and the previously supplied v7.602 VIEWPORT r4 capture.

## Passed source-level checks

- **PASS: 262 / 262 normalized Python source regressions, 0 failures**, executed in 8 isolated workers. See `AmazonDark-v7.605-validation.log` for the complete final pass.
- **PASS: `bash scripts/lint-logos.sh`**.
- **PASS: targeted `tests/test_v7605_sustainability_border_corners.py`**, including byte-exact C++ include/string parity, `node --check` and C++ gnu++98 include compile.
- **PASS: v7.604 and v7.603 inherited regressions**, along with v7.602 and v7.601.
- **PASS: CSS rule restricted to the captured sustainability owner** and only changes the existing inner `.a-box-inner` background transparency and shadow. Parent authored 1px border, gray border color, 15px radius, and OLED floor remain intact; no pseudo-border is introduced.

## Limitations

- iPhone/Theos package build and live WKWebView visual inspection were **not performed** here; appearance after installing v7.605 must be verified on-device.
- The original prior r4 probe shows the rounded card's parent radius 15px and original 1px gray border, whereas the inner box has black backing and radius 8px. The image supplied for this request visibly shows missing arcs on all four corners. The fix removes the cover layer instead of drawing new geometry.
- A minimal headless Chromium geometry reproduction shows that opaque nested content can cover rounded border pixels and a transparent inner floor exposes the existing border. This is a synthetic sanity check, not proof of real Amazon paint.
