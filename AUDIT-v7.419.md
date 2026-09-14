# AmazonDark v7.419 audit

Version: `7.419~payment-giftcard-art-input-fill`  
Direct parent: `7.418~payment-giftcard-switch-cleanup`

## Probe/screenshot-backed corrections

1. `input-claim-code-wrapper`
   - v7.416 probe captured wrapper background `rgb(255,255,255)`.
   - The actual `input-claim-code-text-input` is `rgb(24,26,27)` / `#181a1b`.
   - v7.418 changed the wrapper to OLED, eliminating white but creating a black notch.
   - v7.419 changes only the wrapper fill to `#181a1b`, exactly matching the input interior.

2. Enabled Amazon gift-card art
   - Gift-card art is under `data-testid=art`, with the image/background-image renderer nested inside it.
   - v7.418 TWB only named `unselected-balance-pm-giftcard` through `data-testid=image`.
   - v7.419 moves gift-card TWB ownership to the exact `art` wrapper and includes both selected and unselected gift-card families.
   - Primary payment-card image TWB remains independently scoped.

## Preserved

- v7.418 role=switch-only outline cleanup.
- Authored switch track/knob colors.
- Pure-white payment neutral text and semantic links.
- v7.417 Search carousel repair.
- v7.416 canonical location architecture.

## Performance

No new native hook, WKUserScript family, MutationObserver, timer, RAF, polling loop, scroll listener, or recurring scan. The delta is two static selector corrections only.
