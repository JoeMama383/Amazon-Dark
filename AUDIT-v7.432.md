# AmazonDark v7.432 audit

## Parent

`7.431~pdp-r2-r5-fix` from the exact v7.431 source package generated in the prior handoff.

## Root cause corrected

The v7.429 r2 FULL capture proved that the large sponsored hero video/product unit is `#ape_detail_mobile-hero-quick-promo_mshop_iframe`, while the upper ILM ad is `#ape_detail_mobile-app-detail-ilm_mshop_iframe`. v7.431 correctly themed their main-document shells, but its child-document PDP theme still required `document.referrer` to directly match `/dp/`, `/gp/product/`, or `/gp/aw/d/`. Nested SafeFrame hops can break that assumption, leaving the actual iframe body/footer white with stock dark copy.

## v7.432 change

- Adds one document-start child-frame stylesheet (`ADPDPSafeFrameJS7432`) to the existing combined all-frame WebKit program.
- It has no referrer dependency. It is inert until the hydrated child document contains an Amazon ad-renderer signature such as `#ad`, `renderer-factory-ad-container`, `ad-background-container`, ad-feedback identity, or `creative-container`.
- Once proven, root/renderer floors become OLED black, neutral structural wrappers become transparent over that floor, explicit stock-white structural paint is converted to black, and stock dark neutral copy is made light.
- Authored links/prices/statuses, Prime, ratings/stars, badges/deals/coupons, and raster/video/SVG media remain excluded from the neutral conversion lane.
- Adds the previously omitted `#ape_detail_mobile-app-detail-ilm_mshop_iframe` to the exact main-frame APE backing selector.

## Runtime contract

No MutationObserver, setInterval, timer loop, requestAnimationFrame loop, web scroll listener, recurring hierarchy scan, or parent-frame cross-origin DOM access was introduced.
