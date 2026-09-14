# AmazonDark v7.419 — payment gift-card art / claim-code fill

Direct parent: **v7.418~payment-giftcard-switch-cleanup**. All v7.418 payment/switch cleanup, the folded Search-carousel caption repair, and the v7.416 canonical location architecture remain intact.

## Changes

- **Enter code fill continuity:** the probe shows `input-claim-code-text-input` is `rgb(24,26,27)` (`#181a1b`). v7.418 removed the white sliver by making `input-claim-code-wrapper` OLED black, which left a visible black notch. v7.419 instead paints the exact wrapper `#181a1b`, matching the field fill exactly while leaving its gray outline ownership unchanged.
- **Enabled Amazon gift-card art:** checkout TWB now owns the exact gift-card `data-testid=art` wrapper for **both** `selected-balance-pm-giftcard` and `unselected-balance-pm-giftcard`. This covers the enabled-state SVG/background-image renderer while keeping the switch track/knob authored. The previous primary-payment-card image TWB remains separate.
- **No broad media or switch changes:** switch outline cleanup from v7.418 is retained; no additional glyph/sprite recoloring or inversion is introduced.

No MutationObserver, timer, RAF, polling loop, Web scroll listener, recurring hierarchy scan, new native hook class, or new WKUserScript family is added. FULL, VIEWPORT, and TRANSITION probe identities are regenerated to v7.419.
