# AmazonDark v7.421 audit

Version: `7.421~byg-carousel-theme-restore`  
Direct parent: `7.420~cart-topnav-payment-divider-fix`

## Probe-proven regression

The v7.420 FULL probe for the checkout **Need anything else / Buy again** page is not using the older dense-grid BYG renderer. It mounts the `speed-byg-sf-mobile-carousel` family. Its outer `carouselContainer` computes to opaque white, and its actual 32x32 `button[name='submit.addToCart']` computes to Amazon yellow `rgb(255,216,20)`. The existing AmazonDark BYG control rule was scoped to `_denseGridAxSpotAtcButton_`, so the alternate renderer escaped it even though the rest of the page remained dark.

## v7.421 fix

- Add only the probe-proven `speed-byg-sf-mobile-carousel_style_carouselContainer` family to the existing BYG OLED floor owner.
- Replace the dense-grid-only plus-button selector with the stable semantic `button[name='submit.addToCart']` under `checkout-byg-mobile-container`.
- Preserve the stock circular geometry; apply `#303335` fill, `#747a7c` border, white plus glyph, and `#202324` pressed/focus fill.
- Generalize existing BYG stepper styling to the stable BYG container so both dense-grid and speed-carousel variants remain dark.
- Keep the dense-grid ATC overlay transparency exception, preventing the historical black horizontal cut through product images.
- Preserve product imagery and authored semantic colors.

## Runtime cost

No new MutationObserver, timer, RAF, polling loop, recurring scan, native hook class, or WKUserScript family. This is selector-only reuse inside the existing checkout document-start stylesheet.
