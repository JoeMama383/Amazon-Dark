# AmazonDark v7.360~search-tiles-cart-coupon-fix

Direct source base: **v7.359~product-mab-controls-menu-fix**. This full tree therefore includes the v7.359 MAB action/menu work even if v7.359 has not yet been pushed separately.

## Visual fixes

- **Product Search — Researched-by-Alexa / Search Tiles carousel:** the supplied v7.358 `/s` probe identifies the exact renderer as `data-component-type=s-tiles-carousel-component` with tile media under `.scx-stt-image-container`. The `IMG.scx-stt-image` leaves already report the configured `brightness(0.42)`, but their image containers still report an authored gradient background. v7.360 clears that gradient to OLED black and makes every image leaf inside this exact tile image-container family join the existing `/s` TWB media lane. This is family-scoped: it does not broaden TWB to every Search image or touch the Alexa/title glyph lane.
- **Cart — coupon price / Clip Coupon control:** the historical Cart probe identifies the stable owner as `.sc-clipcoupon-container` / `data-csa-c-painter=cart-coupon` with `.sc-coupon-wrapper > .a-button`. v7.360 separates this control from the neutral Undo rule and gives it the same coupon palette already used on Search: `#008000` green surface/edge with white coupon copy. Nested glyph/image/icon leaves have filters explicitly left alone so the authored black coupon glyph is preserved.

## Preserved

- v7.359 Product MAB Heart, chevron/open blue ring, More-like-this/two-card control and overflow menu.
- v7.358 Search recent-row cleanup, exact Shop-by-style pseudo-floor repair and certification leaf correction.
- v7.355–v7.357 product/Cart/Search fixes, v7.351 optimization and Save-for-later repair, v7.350 splash seal, and v7.348–v7.349 Cart loader/strip work.
- Cart authored loader imagery remains untouched.

## Architecture / cost

No new native hook, `MutationObserver`, interval, RAF loop, Web scroll listener, polling loop, recurring DOM scan, or native hierarchy scan is introduced. Both visual changes are static selectors inside the existing document-start CSS/TWB payloads. Screenshot/SIGUSR2 probes remain dormant until explicitly triggered.

Historical screenshot probe filenames remain `AmazonDark-v7.309-*`; capture headers report the installed v7.360 runtime. The skeleton helper identity advances to v7.360 and accepts the immediately previous v7.359 receipt plus the older proven receipts for upgrade-time Amazon-container discovery.
