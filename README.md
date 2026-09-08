# AmazonDark v7.366 — Cart empty-caption fix

Direct base: **v7.365~probe-backed-cart-sameday-sustainability**.

The v7.365 FULL probe shows why the top empty-Cart sentence stayed dark: `.sc-cart-header` is already light but is a zero-height owner in this state. The visible sentence is the separate direct leaf `form#activeCartViewForm > .sc-list-caption > p.a-spacing-base.a-size-medium`, which remains stock `rgb(15,17,17)`.

v7.366 adds one exact Cart selector for that visible neutral sentence and changes both `color` and `-webkit-text-fill-color` to `#e8e6e3`. The removed-item product-title blue lane remains preserved, and no broad Cart paragraph/text rule is added.

All v7.365 same-day progress, same-day text, Saved Cart, Sustainability sheet, launch behavior, TWB behavior, and universal FULL/VIEWPORT probes are retained. Probe filenames advance to v7.366 only.
