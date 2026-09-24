# AmazonDark v7.472 — PDP standalone-engine unification

Direct parent: **v7.471~pdp-four-adcard-repair**.

The remaining PDP ad failures were not caused by a lack of selectors. They were caused by a route split that kept the mature, device-proven standalone-ad engine away from product/search-referrer child frames.

`ADStandalonePaintJS7104()` is the established working implementation used by the standalone ads that already theme correctly. It owns OLED floors, structured-vs-raster classification, semantic text preservation, Prime/star exclusions, TWB media treatment, border ownership, and a constructable `document.adoptedStyleSheets` survivor sheet. But it deliberately exits on `/dp/`, product, and `/s` referrers. The outstanding PDP ads therefore fell into separate PDP child-frame code paths instead of the mature standalone contract. That also meant `ADTWBJS` did not see `data-ad7104-standalone` and could darken media leaves such as the 53x15 Prime artwork in the large 402x283 card.

v7.472 does not rewrite the mature standalone function. Its frozen function bytes remain unchanged. Instead, the existing native page-world frame bridge now post-hydration-promotes only child frames that prove an exact ad renderer (`#ad`, `#offsite-buy-box`, `#dynamic-bb`, renderer-factory, gridContainer, or the AUI `sp_hqp_phoneapp_shared` family). The bridge enumerates both `_frameTrees:` (site-isolated WebContent process trees) and `_frames:` (ordinary tree), then uses `evaluateJavaScript:inFrame:inContentWorld:` in `WKContentWorld.pageWorld`. For those frames only, a runtime copy of `ADStandalonePaintJS7104()` bypasses the historical product-referrer return, so the same working standalone engine that themes Home/Menu ads now owns the PDP ad frame too.

A small v7.472 delta is appended directly to the mature constructable standalone sheet for the four outstanding families:

- 430x74 offsite compact card: brand/product copy light; Sponsored/info semantics retained.
- 402x125 grid/Swiper card: OLED grid/slides, gray real card edge, neutral text light, existing arrows/media semantics preserved.
- AUI `sp_hqp_phoneapp_shared` medium card: OLED A-box/gradient floor, neutral title/rating count/price light; orange star sprite and blue/orange Prime sprite untouched.
- 402x283 grid single-product card: OLED structural floor, neutral title/price light, product art remains TWB-tamed, exact dealprice Prime image is released from the generic child-media filter.

The existing dominant-raster classifier is reused unchanged. If a qualifying standalone frame is actually a single raster, the mature engine marks/tames only that raster and removes renderer chrome instead of trying to recolor nonexistent structured text.

The v7.470 Book-details PUTB `::before` gradient removal remains intact.

No MutationObserver, interval, requestAnimationFrame loop, Web scroll listener, polling loop, or recurring hierarchy scan is added. FULL, VIEWPORT, and TRANSITION probes are regenerated as v7.472.
