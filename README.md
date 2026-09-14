# AmazonDark v7.420 — Cart top-nav / payment divider fix

Direct parent: **v7.419~payment-giftcard-art-input-fill**.

## What changed

- **Cart tan band regression:** the v7.419 FULL probe captured an exact plain `UIView` directly hosted by the full-screen `ANXTabRootViewController` with Amazon tan `rgba(0.929,0.733,0.506,1)`. The transparent `ANXSubNavContainer` can expose this plane as the tan band beneath the search bar. Older code recognized the same tan only while a checkout presentation was active. v7.420 gives this exact tab-root tan plane its own event-driven owner and paints it OLED black on attach and on later background assignments.
- **Payment Add-gift-card overlap:** the v7.419 payment FULL probe proves the bright line beneath the card is a separate `380x1` first child of `[data-testid=sticky-footer]`, background `rgb(213,217,217)`, not the card border. v7.420 collapses only that exact footer divider so the card's existing gray border remains the sole edge.

## Preserved

- v7.419 claim-code `#181a1b` fill continuity and selected/unselected gift-card artwork TWB.
- v7.418 switch-outline cleanup and authored track/knob colors.
- v7.417 Search carousel caption repair.
- v7.416 canonical location ownership and current location-menu theming.
- Existing checkout-transition tan handling remains separate and checkout-scoped.

## Runtime cost

No MutationObserver, timer, RAF loop, polling loop, Web scroll listener, recurring native scan, new native hook class, or new WKUserScript family is added. The Cart fix reuses existing `UIView` lifecycle/background hooks; the payment fix is one static selector.

FULL, VIEWPORT, and TRANSITION probe identities are regenerated to **v7.420**.
