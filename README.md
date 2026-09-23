# AmazonDark v7.471 — persistent PDP ad-card ownership

Direct parent: **v7.470~pdp-isolated-frame-ownership**.

v7.471 fixes the timing defect proven by the two v7.470 VIEWPORT captures and applies the established standalone-ad coloring policy to all four currently outstanding PDP ad-card families.

## Root cause found in v7.470

v7.470 finally proved that the production program reaches the isolated ad documents: both new captures report `frameMeta.theme7470=1`. The problem was inside that program. It set the marker at document start, but it did **not** insert `ad7470-pdp-isolated-theme` until one of its target selectors already existed. The affected renderers hydrate after the finite DOM-ready/load callbacks, so the child document could carry the v7.470 marker while never receiving the persistent stylesheet. The main PDP did receive the style because `#dp` already existed, which explains why source-level validation looked correct while the cross-origin cards remained white.

v7.471 inserts the stylesheet unconditionally at document start in the already-proven `AmazonDarkUIProbe7453` isolated `WKContentWorld`. Late Amazon hydration now matches an already-present style instead of requiring another callback or scan.

## Four outstanding ad-card families

1. **Compact/top offsite card** — reuse the established renderer-factory algorithm: OLED renderer/main/content floors, standard gray edge, white neutral brand/product copy, preserved ratings/Sponsored semantics, and the requested gray Sponsored circle with OLED inner `i`.
2. **Odd half-carousel/grid card** — OLED `gridContainer`/zinc/slide floors, remove the square duplicate slide edge, retain the rounded gray `gridRegionCarousel` edge, white neutral product/price text, and leave arrows/media/semantic colors alone.
3. **AUI `sp_hqp_phoneapp_shared` 402x125 card** — OLED `.a-box`/background floor, remove its light gradient, white title/rating-count/price copy, keep the orange star sprite and blue/orange Prime sprite untouched, and keep the product image on the existing configurable TWB path.
4. **Large 402x283 grid product card** — OLED structural floor, white title and price, keep the product image tamed, and explicitly release the 53x15 Prime artwork from TWB so its orange check and blue `prime` text render at authored intensity. If Amazon supplies this family as a single raster instead of the structured grid, these DOM rules do not recolor it; the existing TWB path simply tames that raster.

The Book-details fix from v7.470 remains: the actual PUTB read-more `::before` gradient is removed rather than the unrelated expander-fade owner previously targeted.

No MutationObserver, interval, RAF loop, Web scroll listener, recurring DOM traversal, or recurring frame-tree walk is added. FULL, VIEWPORT, and TRANSITION probes are regenerated as v7.471. Cross-frame captures now also report `frameMeta.theme7471=1` so delivery and computed paint can be verified separately.
