# AmazonDark v7.369 — checkout isolation / v7.368 regression audit

## Production baseline

- Direct base: `7.367~sns-zero-base-wrapper-parity`.
- Parent `src/Tweak.xm` SHA-256: `a08b11ba26c70a0fa5c0c33d8598acfcd7039a4d695f28de870e9952718d3bad`.
- v7.368 is intentionally discarded rather than patched in place.

## Confirmed v7.368 failure

The v7.368 checkout additions were appended inside the shared `ADFloorJS()` JavaScript program. Attribute selectors such as the Add-to-Cart and quantity-stepper selectors used Objective-C `\"` escapes, which compile to literal `"` characters. Those literal quotes landed inside an already-open JavaScript double-quoted CSS string and terminated it early. Result: the entire shared floor program failed JavaScript parsing, so stock white WebUI surfaces appeared app-wide.

The Home/hero TWB program was separate and continued to run. That explains the simultaneous symptom of product imagery looking covered/dark while the WebUI floor program itself had disappeared.

## v7.369 architecture correction

- Rebuilt directly from v7.367.
- `ADFloorJS()` SHA-256 remains `5fcc2badb75d385b84a9e67a1daab376c1dd277479c6c1071ead93e3ee96221d` — byte-identical to v7.367.
- `ADTWBJS()` SHA-256 remains `74035e2572891f3b6014522bf4838d19a72a1dc1dfb894363eb8fec53cae5dd9` — byte-identical to v7.367.
- `ADCoreWebJS7271()` SHA-256 remains `e3d9e2edec398c434986eb423aa1d9a4a4fbde73db21d19be5727934a517f480` — byte-identical to v7.367.
- Checkout floor and checkout TWB are independent `WKUserScript`s (`ADCheckoutFloorJS7369` / `ADCheckoutTWBJS7369`).
- Checkout attribute selectors use single quotes inside a JavaScript template literal, eliminating the v7.368 quoting failure mode.

## Probe-backed ownership retained

### Before-you-go / recommendations

- `#checkoutDisplayPage.checkout-display-page`
- `.checkout-byg-mobile-container`
- `_mobileDenseGridLayoutContainer_`
- `_mobileDenseGridAsinFaceout_`
- `_denseGridAxSpotAtcButton_`
- `_mobileDenseGridImage_`
- fixed `.checkout-byg-continue-button-shadow-mobile` sibling
- `#checkout-byg-ptc-button`

The fixed footer is explicitly owned because the probe proves it is a sibling of the grid container, not a descendant.

### Place Your Order

- `#checkout-experience-container`
- `.checkout-experience-panel`
- `.checkout-experience-block`
- `.rcx-checkout-custom-card`
- `.checkout-card-color`
- `.lineitem-container`
- Place Order wrapper/button families
- `fieldset[name='checkout-quantity-stepper']` plus inner stepper controls
- `img.sustainability-green-leaf-alignment-updated`

The probe shows the quantity fieldset itself computes white, so v7.369 owns the fieldset as well as the inner control.

## Dynamic-color contract

- Prime remains unfiltered.
- Amazon blue links remain `rgb(33,98,161)`.
- Success green remains `rgb(11,123,60)`.
- BYG red deal-badge family is excluded from neutral whitening.
- Sustainability leaf remains unfiltered.
- Checkout product images alone enter the dedicated checkout TWB script.

## Native header scope

The probe identified `AMSModalLayoutFullScreenViewController` / `UINavigationBar` with an image-backed `_UIBarBackground`. v7.369 hides that backing only when both conditions are true:
1. the responder chain contains `AMSModalLayoutFullScreenViewController`; and
2. the navigation title contains `Place Your Order`.

The title and Done button therefore remain light while unrelated bars are excluded.

## Performance

No MutationObserver, interval, RAF loop, web scroll listener, renderer polling loop, or recurring hierarchy scan is added by the UI repair. The two universal probes remain explicit-trigger only.
