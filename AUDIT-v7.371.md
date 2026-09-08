# AmazonDark v7.371 audit — residual checkout / BYG UI

## Baseline
- Direct parent: `7.370~checkout-script-reinstall-theme`
- Parent `src/Tweak.xm`: `c6a6dd0dcbead983bfe4d785eff407f7dfd94768a0a8139b9506c41d3517607b`

## Probe-backed findings

### BYG image cut — FULL r1
The product image and its `_mobileDenseGridImageContainer_` are full-height. The add control
is an absolutely overlaid `byg-dense-grid-atc-container`. Its inner
`.atc-faceout-container` and `.ax-replace` are both 32px tall at the exact plus-button
vertical position, and v7.370's broad BYG `.a-section` floor rule computed them OLED black.
That overlay is what visually bisected each photo. v7.371 restores only those overlay
plumbing rows to transparent; the circular add button keeps the requested gray treatment.

### Checkout residuals — FULL r3
- `_UIBarBackground` computed OLED black, but its direct 430x103 image-bearing `UIImageView`
  remained `hidden=0`, proving the image plane—not the bar floor—still produced the tan header.
- The `UIButtonLabel` was light while `_UIModernBarButton` still reported a dark titleColor/tint; v7.371 owns both states for the exact checkout nav.
- `#payment-option-text-default` and `#payment-option-text-1` computed `rgb(15,17,17)`.
- `#concealmentDropdown-0-dropdown` and its `.a-button-inner` computed white.
- The exact Subscribe & Save checkbox row computed `rgb(246,246,246)` while pressed.
- Its `a-icon-checkbox` remained authored/unfiltered; v7.371 preserves that blue ring.

## Architecture
Checkout remains isolated from the shared WebUI program. The repair is declarative CSS plus
a narrow native checkout-nav image lifecycle reassertion. No recurring scanner/timer is added.
