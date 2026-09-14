# AmazonDark v7.418 — payment gift-card / switch cleanup

Direct shipped parent: **v7.416~location-canonical-owner**. The unshipped v7.417 Search-carousel caption repair is folded into this release, so v7.418 contains both deltas in one device build.

## Changes

- **Search autocomplete carousel:** retains the old exact `.cards_carousel_widget-sug-text` owner and adds only non-media structural caption fallbacks. Product images remain transparent/visible and use the existing brightness-only TWB path.
- **Payment gift-card row:** the current probe uses `unselected-balance-pm-giftcard`, which the historical selected-only rule did not own. This exact family is now OLED with standard gray edge and pure-white neutral text.
- **Gift-card artwork:** the exact gift-card image wrapper joins the existing checkout TWB brightness factor. Switch/glyph paint remains authored.
- **Enter code:** `input-claim-code-wrapper` is OLED, removing the probe-captured white strip around the already-dark input.
- **Switch outline cleanup:** `outline-outer` and `outline-inner` are stripped only when they are descendants of `[role=switch]`. This removes the app-wide Web/React checked-switch ring without changing the authored track/knob or unrelated text-input outline nodes.

No MutationObserver, timer, RAF, polling loop, Web scroll listener, recurring hierarchy scan, or new WKUserScript family is added. FULL, VIEWPORT, and TRANSITION probe identities are regenerated to v7.418.
