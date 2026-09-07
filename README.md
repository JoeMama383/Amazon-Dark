# AmazonDark v7.356~product-inline-ad-controls-fix

Direct base: accepted `v7.355~cart-same-day-search-strip-fix`.

v7.356 is the Search/product-scroll UI repair built from the September 7 screenshot/probe set. It keeps the accepted v7.355 Cart Same-Day and Search-carousel work and adds only route-local document-start CSS/TWB ownership for the newly exposed `/s` and `/autocomplete` surfaces.

## Included UI fixes

- **Search autocomplete delivery-day footer:** the remaining bright footer/list plane beneath suggestions becomes OLED black; its contained Today/Tomorrow controls retain dark neutral button chrome and light text.
- **YOU MIGHT ALSO NEED carousel:** replaces v7.355's image-adjacent title-strip selector with the exact `.cards_carousel_widget-sug-text` owner. Product rasters remain visible and brightness-tamed.
- **Product option/count pills:** white toggle pills become OLED black with light text and `#747a7c` neutral edges; the selected state keeps Amazon's blue `#2162a1` ring.
- **Ear-cleaning/theme-collection sponsored carousel:** the probe-proven `_c2Itd_themeCollectionAsinItem_*` near-white outer edge becomes `#494d4d`. Its product imagery remains on the existing TWB lane.
- **Continue shopping / IES inline-expansion sheet:** the white shell, header, gradient frame and white carousel-card planes become OLED black. Neutral copy becomes light while Prime/star/deal/coupon/promotion/savings/success/discount families remain Amazon-owned.
- **IES category tabs and close control:** unselected tabs use black/gray/light chrome; selected tab retains the Amazon-blue ring. The close control uses `#303335` / `#747a7c` / light glyph.
- **IES Add to cart controls:** yellow stock buttons become the established `#303335` / `#747a7c` / light-text control treatment.
- **IES product images:** the actual rasters under `.ccs-ies-card-image-container img` now join the regular `/s` brightness TWB lane, so the large white-panel product images are tamed rather than hidden or painted over.
- **Product quantity stepper:** the stock white/yellow stepper becomes `#303335` with a 1px `#747a7c` edge, light value, and white add/remove glyphs.
- **Shop by style:** includes a Search-local semantic visual-search owner for `shop-by-style`/`shopByStyle` renderer tokens and brightness-tames only its raster media. The supplied screenshot did not have a matching technical-ID probe capture, so this lane is deliberately semantic rather than claimed as an exact live-class proof.

## Preserved contracts

- v7.355 Cart Same-Day Delivery owner and button treatment.
- v7.354 Store Spotlight media/TWB and tracker exclusion.
- v7.353 Top-reviewed header/gradient and tile treatment.
- v7.352 stock Lists Heart / More-like-this / MAB action ownership, featured-video pill and certification-image preservation.
- v7.351 optimization and Cart Save-for-later text repair.
- v7.350 native splash image seal, v7.349 Cart shimmer-strip repair, v7.348 Cart gradient/loading-bar repair.
- No broad product-image, ad, Heart, Prime, star, Sponsored, Cart-loader-image, or native-view recolor was added.

## Performance

No new native hook, production `MutationObserver`, interval, RAF, Web scroll listener, polling loop, recurring DOM scan, or recurring native hierarchy scan. The new visual ownership remains in the existing route-local document-start CSS/TWB payloads. The screenshot/SIGUSR2 probes remain dormant until explicitly triggered.

## Probe workflow

The historical Search/product-scroll probe filenames remain `AmazonDark-v7.309-*` for continuity; their file headers report the installed v7.356 runtime. Use a screenshot or `SIGUSR2` while the target is visibly on screen, then export the matching probe from Amazon's Documents container.
