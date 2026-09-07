# AmazonDark v7.350~native-splash-image-seal

- Direct base: exact v7.349~cart-shimmer-border-strip-fix. The accepted Cart 13pt strip fix and all v7.349 UI behavior are retained.
- The paired v7.349 launch capture contains one known-good cold launch followed by one known-bad cold launch. SpringBoard reports dark `GeneratedDefault` launch artwork in both runs, eliminating the system launch resource as the differentiator.
- Only the bad run exposes `AXUSplashScreenViewController` on-window with a full-screen `UIImageView` (`430x932`, source image `2400x2400`, `contents=true`). The good run never exposes that image plane.
- v7.350 seals only the exact Amazon native splash controller during cold/scene-reconstruction presentation: an OLED-black noninteractive top view plus the existing AmazonDark splash logo is installed during `viewDidLoad`/appearance ownership before window attachment and brought to front on layout. Amazon still owns the controller lifetime and dismissal.
- Ordinary warm resume behavior is unchanged: if Amazon attempts to replay the splash on the existing scene, the retained v7.307 warm suppression hides the whole controller and the seal with it.
- No SpringBoard scene overlay, PID classifier, Home-readiness poll, timer, hard cap, recurring scan, observer, RAF, or transition delay is introduced.
- Transition probe retained and bumped to v7.350 for acceptance. Named layers `AmazonDarkSplashSeal7350` / `AmazonDarkSplashSealLogo7350` make the new owner visible in the existing native-frame recorder.

---

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
