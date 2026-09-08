# AmazonDark v7.374 — BYG neutral price + checkout first paint

Direct parent: **v7.373~checkout-delivery-press-state**
Parent `src/Tweak.xm` SHA-256: `bd4d29a9e14bc5b1977890d545781e707ddbb7e731f848a3b8932f9c3f41534d`

The supplied v7.373 probes isolate the remaining issues:

- BYG current-price text uses `span.a-price[class*=_mobileDenseGridPriceToPay_]` and
  computes stock `rgb(15,17,17)`. v7.374 flips only that neutral current-price family
  light. Authored red discounts/deals remain untouched.
- The center/lower recommendation card shown without a plus button has no
  `submit.addToCart`, `_denseGridAxSpotAtcButton_`, or other ATC descendant in the captured
  DOM. v7.374 does not synthesize a fake control Amazon did not provide.
- Checkout FULL r2 proves the initial `_UIBarBackground` is already OLED black but its
  direct image-bearing `UIImageView` is still `hidden=0`; after the probe's finite sweep
  it becomes `hidden=1`. v7.374 runs the existing checkout-nav owner from
  `UINavigationBar`'s initial `didMoveToWindow` / `layoutSubviews`, so the yellow image
  plane is suppressed during initial layout instead of waiting for a scroll-triggered
  relayout.

No shared WebUI renderer is broadened and no recurring runtime mechanism is added.
