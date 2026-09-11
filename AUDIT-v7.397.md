# AmazonDark v7.397 audit — checkout/payment auxiliary controls

## Base

Direct parent: `7.396~checkout-address-transition-floor-fix`.

No v7.396 production theming was removed. The address-navigation native transition-floor owner remains unchanged apart from the normal release identity bump.

## Probe evidence

The v7.395 FULL captures at 20:17 and 20:18 identify three visible residual white owners.

1. **Select a Payment Method — financing control**
   - `button[data-testid='feature-financing-link']`
   - visible white owner: `div[data-testid='feature-financing-link-content-wrapper-outline']`
   - rect approximately `286 x 44`
   - computed background `rgb(255,255,255)`
   - stock border `rgb(213,217,217)` and light shadow
   - SVG chevron path remains dark (`fill rgb(15,17,17)`).

2. **Place Your Order — Prime Store Card delivery upsell**
   - owner under `#percolate-upsell-widget`
   - class family `[class*='_bannerBlue_']`
   - rect approximately `400 x 70`
   - computed background `rgb(255,255,255)`
   - authored `3px rgb(28,137,227)` border.

3. **Place Your Order — default-ordering checkbox card**
   - `#purchase-level-messages .a-alert.a-alert-info`
   - nested white owner `.a-box-inner.a-alert-container`
   - rect approximately `400 x 86`
   - authored asymmetric Amazon-blue alert edge (`rgb(36,111,182)`)
   - contains `#setOrderingPrefsCheckbox` + `.a-icon-checkbox` stock artwork.

## Correction

- Financing inner control: OLED black, standard `#747a7c` border, light shadow removed, text white, SVG chevron path white.
- Prime Store Card upsell: OLED black + white neutral text; authored blue border is deliberately not recolored.
- Purchase-level checkbox card: both nested white owners become OLED black, neutral text becomes white; authored blue edge is deliberately not recolored and checkbox sprite/filter is explicitly preserved.

## Scope / performance

The correction is static CSS appended to the existing checkout document-start program. It adds no MutationObserver, polling, timer, RAF loop, scroll listener, recurring traversal, new WKUserScript, native hook, or broad payment-card rewrite.

## Device validation

After installing v7.397:

- open **Select a Payment Method** with a Store Card financing row visible; the inner financing button must be OLED black with gray edge, white copy and white chevron;
- return to **Place Your Order**; the Prime Store Card delivery upsell and default-ordering checkbox card must be OLED black;
- verify both checkout cards retain their Amazon-blue border treatment and the checkbox glyph remains stock.
