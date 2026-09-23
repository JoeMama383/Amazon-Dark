# AmazonDark v7.460 — Home hero Sponsored pill ownership correction

v7.460 is built directly from v7.459. The v7.458 VIEWPORT evidence correctly identified the visible Home hero Sponsored pill itself as `_single-video-card_style_sponsored-label-pill__*` with computed `rgba(255,255,255,0.6)`, but v7.459 mistakenly required that element to be beneath `#gwm-dashboard`. The captured ancestry instead shows the single-video card under the `wd-shoppable-1` / `ape_gateway_mobile-wd-1_mshop_placement` path and does not establish that dashboard ancestor.

v7.460 targets the exact single-video Sponsored-pill class family directly and keeps the requested alpha unchanged at 0.6 while replacing white with black. It also uses a fresh style identity (`ad7460-home-hero-pill`) so the older `ad7381-home-ad-shell-floor` node cannot suppress the corrected rule in a surviving document.

The v7.459 VIEWPORT terminal-state changes are retained. FULL, VIEWPORT, and TRANSITION probe identities are regenerated as v7.460.
