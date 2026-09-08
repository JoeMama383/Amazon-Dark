# AmazonDark v7.367 — Subscribe & Save renderer parity

Direct base: **v7.366~cart-empty-caption-fix**.

The v7.366 FULL probes captured two distinct Cart Subscribe & Save renderers. The correctly themed `sns-upsell-base-and-tiered` renderer owns its `.a-box` directly under `.sns-mobile-cart-improvements-container`. The bad white `sns-upsell-zero-base` renderer inserts one `span.a-declarative` between the container and the same `.a-box`. The existing direct-child CSS therefore never reached the zero-base card.

v7.367 extends only that established Subscribe & Save card ownership to the exact wrapped path. Both renderer families now receive the same `#303335` card floor and `#747a7c` border. Existing switch rules are unchanged: OFF remains Amazon gray, ON remains Amazon blue, and the white thumb is preserved. No switch replacement, observer, timer, or renderer polling is added.

All v7.366 Cart empty-caption work, v7.365 same-day/Sustainability fixes, TWB, launch behavior, and the universal FULL/VIEWPORT probe architecture are retained.
