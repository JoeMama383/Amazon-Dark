# AmazonDark v7.368 — checkout recommendations + Place Order theming

Direct base: **v7.367~sns-zero-base-wrapper-parity**.

This build themes two probe-captured checkout renderer families without changing the universal probe architecture or the v7.367 Subscribe & Save parity fix.

## Before-you-go / recommendation menu

- Exact owner: `checkout-byg-mobile-container` / dense-grid recommendation renderer.
- OLED-black page/card floors and light neutral copy.
- Preserves Amazon-authored Prime blue, link colors and the captured red deal/badge lane.
- Recommendation product images enter the existing user-controlled TWB lane.
- `Continue to checkout` becomes OLED black with the standard gray control border and white text.
- Exact dense-grid Add-to-Cart plus control uses the same `#303335` / `#747a7c` / white-glyph language as AmazonDark's other controls.

## Place Your Order

- Exact `checkoutDisplayPage` / `checkout-experience-container` cards and line-item surfaces become OLED black with standard gray structural borders.
- Neutral dark copy becomes light while Amazon blue links/Prime and success green remain authored/dynamic.
- Place-order controls use OLED black, gray border and white text.
- Exact checkout quantity stepper gets Cart-equivalent `#303335` / `#747a7c` treatment with white trash/add glyphs.
- Exact `sustainability-green-leaf-alignment-updated` image stays unfiltered so the existing green leaf survives.
- Checkout product images use the configured TWB lane.
- The probe-captured `AMSModalLayoutFullScreenViewController` / `AMIWebViewController` navigation backing is made OLED black; the authored yellow raster backing is suppressed only in that modal and the navigation tint is light for Done/title chrome.

## Probe / performance contract

FULL remains screenshot-triggered and VIEWPORT remains one-shot SIGUSR2. There is no route-specific probe dispatcher, MutationObserver, interval, RAF loop, web scroll listener, or recurring hierarchy scanner added by this build.
