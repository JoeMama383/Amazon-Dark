# AmazonDark v7.153~production-performance-hotpath-fix

Direct base: v7.152~performance-compaction-image-fix.

## Priority
Production performance is the primary design constraint. Search theming must be achieved with static, narrowly scoped ownership and must not add live DOM walkers, MutationObservers, timers, RAF loops, screenshot probes, or broad selectors that force every Search element/image to participate in expensive style matching.

## v7.153 performance correction
v7.152 removed the explicit probe runtime, but review against the fast v7.146 production baseline exposed additional recent hot-path regressions:

- The privacy document-start script still contained the expanded v7.151 diagnostic request bookkeeping (`MAX=320`, event arrays/counters, residual resource reporting, diagnostic message reporting). v7.153 restores `ADPrivacyModeJS7117` byte-for-byte to the compact v7.146 production implementation.
- Removed the universal `.haul-puis-widget-faceout-container *` Search matcher. The Haul repair now owns only the faceout root and its direct non-image/action structural children.
- Removed generic coupon substring fallbacks such as `[class*=coupon][class*=price]`; the known coupon classes captured by the probe are targeted directly.
- Removed the alternate-video product-detail rules that matched every DIV/SECTION/SPAN/A under `productDetailsContainer` and then evaluated long exclusion chains. Exact `_c2Itd` classes captured by the probe are used instead.
- Removed the VIDEO_SINGLE_PRODUCT TWB rule whose rightmost selector was every `img,canvas` in Search plus a long exclusion chain. TWB now targets the product raster through `.mobile-video-product-view .s-product-image-container img.s-image` and the alternate renderer through `img._c2Itd_image_pQREQ`.

## Alternate standalone-video image
The v7.152 image-stack repair is preserved: `_c2Itd_image_pQREQ` remains visible/opaque above its local link plane, the wrapper stack remains transparent, unused image-column area remains OLED black, and TWB stays on the actual product raster.

## Production runtime
- 4 WKUserScript installation lanes (same as v7.146)
- 30 existing `:has()` selectors (same count as v7.146; no new relational selectors)
- 0 active `MutationObserver`
- 0 `setInterval`
- 0 `requestAnimationFrame`
- 0 `setTimeout`
- 0 runtime `querySelectorAll`
- 0 screenshot diagnostic listener
- 0 SIGUSR2 probe runtime
- 0 probe-only NSURLSessionTask hook

No diagnostic probe ships in this production build.
