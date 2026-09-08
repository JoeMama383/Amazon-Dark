# AmazonDark v7.369 audit — checkout isolation and menu theming

Direct base: **v7.367~sns-zero-base-wrapper-parity**.

## Failure confirmed in v7.368

v7.368 did contain rules for both the before-you-go recommendation screen and Place Your Order. It failed architecturally: checkout CSS was appended inside the shared `ADFloorJS()` generated JavaScript string, and attribute-selector quote escaping terminated that string. The shared floor script therefore failed to parse. v7.369 discards that intermediate and starts from v7.367.

## Probe-backed owners

The supplied v7.367 FULL probes identify:
- BYG: `#checkoutDisplayPage`, `.checkout-byg-mobile-container`, dense-grid faceouts, exact add-to-cart control, fixed footer sibling, Prime, deal badge, and product image family.
- Place Your Order: `#checkout-experience-container`, checkout panels/cards, Place Order button family, checkout quantity stepper, Prime, links/success text, sustainability leaf.
- Native header: `AMSModalLayoutFullScreenViewController` -> `UINavigationBar` -> image-backed `_UIBarBackground`.

## Architecture

Checkout floor and checkout TWB are separate document-start WKUserScripts. Stable v7.367 shared WebUI and TWB functions are hash-locked unchanged.

## Color/control contract

- OLED structural floors
- neutral copy light
- Amazon blue links preserved
- success green preserved
- semantic red/price/deal/coupon/promotion families excluded from neutral whitening
- Prime and sustainability leaf unfiltered
- Continue/Place Order buttons OLED black with gray edge and light text
- BYG plus uses `#303335` / `#747a7c` / white
- checkout quantity stepper mirrors the exact existing Cart/product-scroll control contract
- native header image backing hidden only for Place Your Order; navigation tint light

## Runtime cost

No recurring observer, timer, RAF, Web scroll listener, renderer polling loop, or recurring hierarchy scanner was introduced.
