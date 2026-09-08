# AmazonDark v7.368 audit — checkout BYG + Place Order

Direct base: **v7.367~sns-zero-base-wrapper-parity** (`src/Tweak.xm` parent SHA-256 `a08b11ba26c70a0fa5c0c33d8598acfcd7039a4d695f28de870e9952718d3bad`).

## Probe-backed diagnosis

### Before-you-go recommendations — v7.367 FULL r1

The white product recommendation screen is one WKWebView using `checkoutDisplayPage` with `checkout-byg-mobile-container`. The three recommendation groups are dense-grid card renderers (`_mobileDenseGridLayoutContainer_` / `_mobileDenseGridAsinFaceout_`). Product media is `_mobileDenseGridImage_`. The fixed continuation control is `#checkout-byg-ptc-button.a-button-primary`; the circular add controls are the exact `_denseGridAxSpotAtcButton_` `submit.addToCart` buttons. Prime is authored `i.a-icon-prime`. The captured promotion/deal copy uses `_badgeMessage_` and Amazon red `rgb(204,12,57)`.

v7.368 therefore owns only the structural white floors, neutral copy and exact controls. Prime/link colors and the red `_badgeMessage_` family are explicitly left out of neutral whitening. Product images enter the existing configured TWB lane.

### Place Your Order — v7.367 FULL r2

The checkout document is `#checkoutDisplayPage > #checkout-experience-container`, with exact `checkout-experience-*`, `rcx-checkout-custom-card`, `checkout-card-color` and line-item surfaces. The probe records neutral text as `rgb(15,17,17)`, Amazon links as `rgb(33,98,161)`, and success text as `rgb(11,123,60)`. Prime is authored background artwork and remains unfiltered.

The quantity control is `fieldset[name=checkout-quantity-stepper]` with `a-stepper-inner-container`, `a-icon-small-trash` and `a-icon-small-add`. The sustainability leaf is the exact `img.sustainability-green-leaf-alignment-updated` image. The Place Order family is represented by `#placeOrder`, `#placeYourOrder`, `#placeYourOrderSecondary`, `place-order-button-link`, `place-your-order-button` and the primary continuation button family.

v7.368 makes those exact structural planes OLED black, neutral copy light, links blue, success copy green, Place Order black/gray/white, the quantity stepper Cart-style `#303335` + `#747a7c` + white glyphs, and leaves Prime and the leaf artwork unfiltered. Checkout product media enters the existing TWB lane.

### Native checkout header — v7.367 FULL r2

The checkout is hosted by `AMSModalLayoutFullScreenViewController` / `AMIWebViewController`. Its `UINavigationBar` contains `_UIBarBackground` with a direct image-backed appearance layer. That image-bearing backing is the remaining yellow/orange header plane despite the existing black bar ownership. v7.368 suppresses that direct backing only while the view belongs to the checkout modal, forces the exact bar floor OLED black, and sets the navigation tint light so Done/title chrome remains light. The association is restored if the view is later reused outside the checkout modal.

## Preservation

- v7.367 Subscribe & Save zero-base/base-and-tiered parity remains intact.
- Search, Cart, Person, Menu, Alexa, launch, splash and previous loader/TWB behavior are otherwise unchanged.
- `src/AmazonDarkSB.xm`, `src/ADSkeletonProbe7339.js.inc`, `Makefile`, and `.github/workflows/build.yml` are byte-identical to v7.367.
- Universal probe architecture remains exactly FULL screenshot sweep + armed VIEWPORT. Internal `ADUniversalUIProbe7362.*` filenames/symbols remain stable; only operational identity advances to v7.368.
- No new MutationObserver, interval, RAF loop, web scroll listener, recurring hierarchy scan, or renderer polling.

## Validation

- All 22 Python regression scripts: PASS.
- Universal UI probe embedded JS: C++98 compile + Node parse PASS through `test_v7362_universal_ui_probes.py`.
- Skeleton probe C-string embedding: C99/GNU++98 PASS; inherited payload byte identity preserved.
- `scripts/ui-probe.sh`, `scripts/skeleton-probe.sh`, `layout/DEBIAN/postinst`: shell syntax PASS.
- `scripts/lint-logos.sh`: PASS.
- Project plist lint via `plutil`: PASS.
- Logos balance: 72 `%hook` + 2 `%hookf` / 74 `%end`: PASS.
- Static function-definition duplicate scan: 376 definitions / 376 unique: PASS.
- Production recurring mechanism counts in `Tweak.xm`: MutationObserver 0, setInterval 0, requestAnimationFrame 0, web scroll listener 0.
- Local Theos compile/package cannot run in this container because `/makefiles/common.mk` is absent. GitHub Actions/on-device Theos remains authoritative compile/link/package proof.
