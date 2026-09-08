# AmazonDark v7.370 — checkout script reinstall + probe-correct colors

Direct production base: **v7.369~checkout-isolated-theme**. This release fixes the remaining two checkout menus without changing the shared Home/Search/Cart/Menu/Alexa WebUI programs.

## Root cause fixed from v7.369

v7.369 correctly isolated checkout into `ADCheckoutFloorJS7369` / `ADCheckoutTWBJS7369`, but Amazon can call `WKUserContentController removeAllUserScripts`. The hook restored the shared core/TWB/privacy installation receipts but forgot the two checkout receipts. The real checkout scripts were removed while their associated-object flags still said “installed,” so they were not re-added. v7.370 clears both checkout receipts and immediately reattaches them with the rest of the document-start scripts.

## Before-you-go / product recommendations

- OLED black structural/card/header/footer floors.
- Neutral black product/header copy becomes light, including product titles nested inside `a-link-normal`.
- Authored red/green/blue semantic families retain their own `color`; AmazonDark only resets text-fill to `currentColor` for those families.
- Prime remains authored/unfiltered.
- Product images use the isolated checkout TWB lane.
- `Continue to checkout`: OLED black, `#747a7c` edge, light text.
- Circular add button: `#303335` fill, `#747a7c` edge, white plus.

## Place Your Order

- Checkout cards/panels/line-item surfaces are OLED black.
- Neutral black copy becomes light while authored links/success colors are left authored.
- Probe-proven `a.a-color-base` expander/sustainability links (stock black) are explicitly flipped light instead of being incorrectly forced blue.
- Prime and sustainability leaf remain unfiltered.
- Place Order controls use OLED black / gray border / light text.
- Quantity stepper keeps the Cart treatment: transparent outer fieldset, `#303335` inner control, `#747a7c` edge, white trash/plus.
- Native checkout banner suppression stays scoped to `AMSModalLayoutFullScreenViewController` + a `Place Your Order` title. Title detection now searches all nav labels instead of stopping on `DONE`, and the exact checkout nav labels are kept light with restoration if reused.

## Regression boundary

`ADFloorJS()`, `ADTWBJS()`, and `ADCoreWebJS7271()` remain byte-identical to v7.369/v7.367. No MutationObserver, interval, RAF loop, web scroll listener, recurring hierarchy scanner, or renderer polling was added. Universal FULL/VIEWPORT probe architecture is unchanged; only operational identity advances to v7.370.
