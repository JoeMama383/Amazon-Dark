# AmazonDark v7.349~cart-shimmer-border-strip-fix

- Fixes the persistent 13pt Cart white strip proven by the v7.348 screenshot + transition probe to be the `#sc-recs-atf-shimmer-placeholder` 13px top border (`rgb(234,237,237)`). The existing rule already darkened the placeholder background but never its border. v7.349 owns that exact border OLED black from document start.
- Retains all v7.348 native loading-gradient work and Cart diagnostics.

---

# AmazonDark v7.348~cart-native-gradient-strip-fix

## Probe-proven Cart strip repair

Direct source base: v7.347~cart-strip-owner-forensics, whose production visuals were v7.346 plus read-only armed telemetry.

The v7.347 temporal capture disproves the prior gate/hook theory: `AWLoadingIndicatorBarView` hooks fire, Cart selection becomes true, and `AmazonDarkCartLoadingBar7345` is repeatedly present as an opaque black 430x5 layer at `FLT_MAX` while the user still sees the strip.

The same capture exposes the missing renderer plane. `AWLoadingIndicatorWidgets_BkgView` is backed by a `CAGradientLayer` whose authored colors remain approximately 0.929 gray -> 0.871 gray even though v7.130 already forces the UIView/layer background black and inserts an OLED backing layer. The black backing is below an active light gradient. `AWLoadingIndicatorWidgets_BkgView` is a sibling renderer under `AWLoadingIndicatorFullScreenModalBar`, so a high-z child cover inside `AWLoadingIndicatorBarView` cannot reliably overpaint that separate sibling subtree.

v7.348 completes the exact native loading-family ownership:

- `AWLoadingIndicatorWidgets_BkgView`: when it qualifies as the existing v7.130 app-loading surface, its `CAGradientLayer.colors` are replaced with same-length OLED-black colors in addition to the existing black UIView/background/backing ownership. This is route-safe because v7.130 already intended this exact loading backdrop to be OLED black.
- `AWLoadingIndicatorBarView`: while `cartTab` is selected, the exact bar plane is itself forced OLED black and its transient `layer.contents` strip is cleared. The existing black cover remains as a defensive seal.
- `AWLoadingIndicatorWidgets_Indicator`: Cart-only OLED floor.
- `AWLoadingIndicatorWidgets_HighlightView`: the captured 860x5 animated gradient is recolored OLED black only while Cart is selected. Geometry and animation are untouched.
- v7.347 `CART_STRIP_OWNER` telemetry and the transition recorder remain available for verification. The recorder already reports gradient colors, bar contents, hierarchy, and the cover layer, so no additional recurring production machinery is required.

Preserved unchanged:

- v7.344 authored Cart loader-image preservation.
- v7.343 Home hero and current Cart shimmer skeleton fixes.
- v7.346 buying-options button correction.
- AmazonDarkSB.xm / cold-launch production behavior.
- No production MutationObserver, polling loop, RAF loop, interval, Web scroll listener, or recurring hierarchy scan is added.

## Verification target

After installing v7.348, arm `transition`, reproduce several Cart refreshes, and export. A correct capture should show the loading backdrop/highlight gradients as black and the Cart bar `contents` absent while selected. If a bright line is still physically visible with those conditions proven, the remaining owner is outside this exact AW loading family and the retained recorder will expose the next sibling/compositor.
