# AmazonDark v7.358~search-row-shop-style-leaf-fix

Direct base: **v7.357~search-footer-shop-style-fix**.

This is a narrow correction build for three on-device findings from v7.357. It preserves the Search footer fix and all accepted product/Cart work while removing the Search-row regression and replacing temporary Shop-by-style discovery with the exact renderer captured by the current v7.357 product probe.

## UI corrections

- **Search recent-history rows:** v7.357 made the autocomplete footer black, but its broad structural border/outline rule and broad all-button rule also exposed rectangular borders around recent-search text and X controls. v7.358 keeps the first-two-layer OLED background seal but no longer changes structural borders/outlines/shadows. Button chrome returns to the earlier **delivery-scoped** rule only, so the delivery footer controls stay dark while stock recent-history rows keep only Amazon's original horizontal separators.
- **YOU MIGHT ALSO NEED:** the working `cards_carousel_widget-sug-im*` transparency/visibility and brightness-TWB ownership remains unchanged.
- **Shop by style:** the current product probe finally captures the real renderer: `data-component-type=s-tiles-carousel-component-shoppable_image`, with `scx-si-image` raster leaves. v7.358 directly owns this exact Search Tiles family and removes v7.357's temporary heading `TreeWalker`. The card/header/carousel structure is OLED black with light text and standard gray edges; `scx-si-image` keeps normal configured brightness TWB. The probe-captured large `s-tiles-carousel::before` backing plane and the enclosing Search-result `::before` gradient/separator are explicitly made OLED black, eliminating the remaining top/bottom bright bands.
- **Forestry practices / certification leaf:** the current probe shows `.s-pc-certification-faceout` and its 16x16 `img.s-image` already have transparent CSS backgrounds and no filter, so the visible white square is inside the raster itself. v7.358 keeps the DOM shell transparent and applies `invert(1) hue-rotate(180deg)` only to this exact certification raster, visually turning the baked white background black while approximately preserving the green leaf hue. It does not alter general product imagery.

## Preserved work

- v7.357 Search autocomplete footer OLED floor.
- v7.356 theme-collection border, option/count pills, IES expansion, IES image TWB, dark category/Add-to-cart controls, and product quantity stepper.
- v7.355 Cart Same-Day.
- v7.354 Search carousel media restoration and Store Spotlight company-logo/product TWB.
- v7.353 Top-reviewed/TRFT treatment.
- v7.352 product-action hands-off ownership, featured-video pill and other established product contracts.
- v7.351 optimization and Cart Save-for-later; v7.350 splash; v7.349 Cart strip; v7.348 Cart gradient/loading fixes.

## Runtime character

No production `MutationObserver`, interval, RAF loop, Web scroll listener, polling loop, recurring DOM scan or recurring native hierarchy scan is introduced. The temporary v7.357 Shop-by-style text walk is removed; v7.358 uses exact route-local CSS/TWB ownership.

## Probe workflow

Screenshot-triggered UI probes remain enabled. Historical filenames remain `AmazonDark-v7.309-*`; the header inside a new capture reports `v7.358-search-row-shop-style-leaf-fix`. The product-scroll probe remains current/near-viewport only; the Search/Menu scanner remains the heavier full-document engine.
