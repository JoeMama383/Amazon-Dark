# AmazonDark v7.478 — Home + PDP six-fix pass

Direct parent: **v7.477~pdp-ad-ui-repair**.

This build is limited to the six failures captured in the supplied v7.477 probes. It does not add a new production DOM walker, observer, polling loop, animation-frame loop, or scroll listener.

## Home — three exact owners

1. **Buy Again / “Schedule an action” pills** — the probe identifies the white rows as `button[data-csa-c-painter="Buy-Again-Rufus-Pills-Card"][class*=_pillRow_]`. v7.478 gives only that pill family an OLED floor, gray border, and white neutral text; the separate blue Alexa CTA is not matched.
2. **Thursday Night Football countdown** — the white number chips are the three `atf-countdownCard-Text-Timer-Numeric-*` elements whose class contains `_Timer-Numeric__`. v7.478 paints those chips OLED and their numbers white without touching the transparent `Numeric-Bottom` hr/min/sec labels.
3. **Prime Big Deal Days medium raster** — the bare billboard `<img>` lives under the `_billboard-card_regularStyle_gwm-BillboardCard...` family and was outside the existing image-taming selector. v7.478 adds that family to the existing configured `whiteTame` rule and makes the cropped billboard wrapper OLED.

## PDP — three root-cause repairs

4. **`Top` tab geometry/type size** — the outer `#btfSubNavTopTab` is already 52 pt high with the same 16/20 typography context as its neighbors. The mismatch is inside `.top-tab-content`: Amazon renders a 12 pt `.a-size-mini` label below a collapse icon. v7.477 tried to copy geometry onto the outer anchor, which did not address that inner structure. v7.478 removes that copier and normalizes only the unique inner structure: the icon is suppressed, the wrapper participates as `display:contents`, and the label inherits the tab's native typography. No pixel width/height is imposed on the tab.
5. **Blank 402×125 medium standalone ad** — the FULL probe shows the product image/title/rating/price exist and compute correctly, but they are siblings underneath `#sp_hqp_phoneapp_shared_inner`, which Amazon positions at `z-index:100`. Our black background on that overlay was therefore covering the content. v7.478 keeps the outer ad card OLED but makes that overlay transparent so the existing content can paint through.
6. **Long white line above the bottom bar** — the FULL native probe identifies this as the horizontal `_UIScrollViewScrollIndicator` inside the root `WKScrollView`, not the `ANXTabBarView` border fixed in v7.477. v7.478 disables only the top-level WKWebView horizontal scroll indicator and preserves the vertical indicator styling.

## Validation boundary

The code paths above are mapped to concrete v7.477 probe owners, but the visual result is **not called device-confirmed until v7.478 is installed and recaptured**. Static regression tests verify the exact selectors/ownership changes and prevent the v7.477 overlay, outer-tab geometry copier, or WK horizontal indicator from returning.
