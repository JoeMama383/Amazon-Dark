# AmazonDark v7.421 — BYG carousel theme restore

Direct parent: **v7.420~cart-topnav-payment-divider-fix**.

v7.421 restores the alternate checkout **Before You Go / Need anything else** renderer captured by the v7.420 FULL probe. The current Amazon DOM uses the `speed-byg-sf-mobile-carousel` family rather than the older dense-grid family that the existing CSS was scoped to.

The exact carousel shell is now OLED black so its stock white background cannot leak through around/below the product tiles. The add-to-cart rule is simplified to the stable semantic `button[name=submit.addToCart]` within `checkout-byg-mobile-container`, so both dense-grid and speed-carousel variants use the standard AmazonDark gray control, gray border, white plus glyph, and dark pressed state. Existing BYG stepper rules are similarly generalized to the stable BYG container. Product images and semantic red/green/blue/Prime states are preserved.

No new observer, timer, RAF loop, polling loop, recurring hierarchy scan, native hook class, or WKUserScript family is introduced. v7.420 Cart/payment fixes and all earlier theming remain inherited. FULL, VIEWPORT, and TRANSITION probes are regenerated to v7.421.
