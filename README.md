# AmazonDark v7.369 — isolated checkout theming on v7.367

Direct production base: **v7.367~sns-zero-base-wrapper-parity**. **v7.368 is rejected and is not the code base for this release.**

## Why v7.368 regressed unrelated WebUI

The checkout CSS was inserted into the existing `ADFloorJS()` JavaScript/CSS string. Two attribute selectors were written with Objective-C `\"...\"` escaping. At runtime those became raw double quotes inside an already-open JavaScript double-quoted CSS string, so the entire shared floor script failed to parse. Because `ADFloorJS()` owns the normal dark WebUI floors, unrelated Amazon WebUI pages fell back to stock white. `ADTWBJS()` still ran, which made the pre-existing Home/hero taming visually appear to cover imagery while its matching floor program was absent.

v7.369 starts again from v7.367 and leaves `ADFloorJS()`, `ADTWBJS()`, and `ADCoreWebJS7271()` **byte-for-byte identical to v7.367**. Checkout is delivered in independent document-start user scripts. A future checkout syntax mistake therefore cannot disable Home, Cart, Search, Menu, Person, Alexa, or other shared WebUI theming.

## Checkout recommendation / before-you-go menu

Probe-backed owners are `#checkoutDisplayPage`, `.checkout-byg-mobile-container`, the dense-grid renderer families, and the fixed `.checkout-byg-continue-button-shadow-mobile` footer which sits outside the grid container.

- OLED black structural floors.
- Neutral dark copy becomes light.
- Authored red deal copy, green/success copy, blue links, and Prime artwork are preserved.
- Product images use a dedicated checkout-only TWB rule; Home/hero selectors are not touched.
- `Continue to checkout` becomes OLED black with `#747a7c` gray edge and light text.
- Dense-grid Add-to-Cart circles become `#303335` with `#747a7c` edge and a white plus.

## Place Your Order menu

- `#checkout-experience-container`, checkout panels/cards, line-item cards and their structural inner surfaces become OLED black with standard gray edges where appropriate.
- Neutral dark text becomes light; Amazon blue links and success green are explicitly preserved.
- Prime stays authored; the sustainability leaf remains unfiltered.
- Place Order buttons use OLED black / gray-border / white-text treatment.
- The quantity control now owns the **outer** `fieldset[name='checkout-quantity-stepper']` as well as its inner stepper. It matches the Cart control: `#303335`, `#747a7c`, white trash/plus.
- The native yellow banner fix is restricted to the probed `AMSModalLayoutFullScreenViewController` **and** a navigation title containing `Place Your Order`; unrelated modal/navigation bars are not targeted.

Universal FULL/VIEWPORT probe architecture remains unchanged; only operational output identity advances to v7.369.
