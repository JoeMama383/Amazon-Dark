# AmazonDark v7.432 — PDP SafeFrame ad fix

Exact parent: v7.431 `pdp-r2-r5-fix`. All prior UI/native fixes are retained.

This build corrects the remaining PDP sponsored-ad failure that v7.431 did not actually reach inside the embedded ad document:

- **Hero sponsored video/product footer:** the nested APE/SafeFrame child no longer depends on a direct `/dp/` `document.referrer`. A marker-gated child-frame stylesheet activates only when the hydrated document proves an Amazon ad renderer, making neutral white structural floors OLED black and neutral dark copy light.
- **Top mobile ILM sponsored ad:** the exact `mobile-app-detail-ilm` iframe now has the same OLED main-frame backing as the hero/btf2 APE frames, while the marker-gated child lane themes its internal neutral floors/text.
- **Preservation:** authored link/price/status colors, Prime, ratings/stars, badges/deals/coupons, images, video, canvas, picture and SVG media remain outside the neutral conversion lane.
- **Performance:** no MutationObserver, timer, interval, RAF loop, web scroll listener, or recurring hierarchy scan was added.

FULL, VIEWPORT, and TRANSITION probe identities are regenerated to v7.432.

See `AUDIT-v7.432.md`, `VALIDATION-v7.432.md`, and `COMMANDS.md`.
