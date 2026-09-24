# AmazonDark v7.471 validation — four PDP ad-card families

## Historical/architectural finding

The unresolved standalone-ad problem is not a v7.464-only issue. The lineage runs through the v7.431-v7.470 PDP/ad work. The established non-PDP standalone-card engine (`ADStandalonePaintJS7104`) already contains the desired policy: OLED structural floors, light neutral copy, gray neutral edges, configurable TWB on product/raster art, and semantic exclusions for Prime/stars/badges/deals/Sponsored. That engine deliberately exits for product/search-like referrers (`if(productish)return`), so the PDP embedded renderers do not receive that proven treatment.

The v7.442/v7.443 private `_WKUserStyleSheet` experiment was never device-proven; v7.444 explicitly returned to the v7.440 parent and still listed the white medium ad, duplicate border, and compact top-ad title as unresolved. v7.470 finally provided something the earlier attempts did not: the new VIEWPORT captures prove that the named isolated `AmazonDarkUIProbe7453` content world executes inside the exact offending child documents.

## Root cause proven by the two v7.470 captures

Both supplied v7.470 cross-frame captures report `frameMeta.theme7470=1`, so the production script **did execute in the child frame**. But the child-frame style inventory does not contain `ad7470-pdp-isolated-theme`; that style appears in the main PDP document instead. The v7.470 code explains the mismatch: `put()` was called only after `apply()` found `#offsite-buy-box`, `#ad [data-testid=gridContainer]`, or `#dp`. The renderer DOM hydrates after the finite DOM-ready/load callbacks, so a frame can receive the v7.470 marker and still never receive the stylesheet.

v7.471 fixes that timing defect by calling `put()` unconditionally at document start. The persistent style exists before Amazon hydrates any of the four card families. The finite lifecycle callbacks remain only as an inline-important fallback for the compact offsite title leaves; there is no observer or polling loop.

## Probe-backed families covered

### 1. Compact/top offsite renderer (historical v7.463 VIEWPORT r1)
- child document: 430x74
- exact white/near-white structural plate: 414x51, `rgb(248,248,248)`, radius 8, light border
- `brand-name` and `product-description`: computed black
- desired semantic content such as ratings/Sponsored remains separate

v7.471 applies the same structural policy as the proven standalone engine to `renderer-factory-ad-container`, its direct structural plate, `main-content`, `content`, and modern layout shell; neutral offsite title leaves are white, Sponsored stays gray, and the info glyph keeps a gray circle/black center.

### 2. Odd 402x125 grid/swiper carousel (historical v7.463 VIEWPORT r2)
- `gridContainer`: white 402x125 outer plane
- inner zinc grid and `swiper-slide.bg-white`: light
- price/currency leaves: black
- rounded `gridRegionCarousel` is the edge that should remain

v7.471 retains the v7.454 scope contract: OLED structural floors, square duplicate edges removed, one gray rounded inner edge retained, neutral price/text white, and no repaint of arrows or product media.

### 3. New 402x125 AUI card (`sp_hqp_phoneapp_shared`, v7.470 VIEWPORT r2)
- `.a-box.sp_hqp_phoneapp_shared_responsive_box_rem`: white
- `#sp_hqp_phoneapp_shared_inner`: authored gradient
- title: black; rating count and price: gray
- product image already follows TWB (`brightness(0.42)` in the supplied capture)
- orange star sprite and Prime sprite are authored background-image assets and are not filtered

v7.471 makes only the structural floor/gradient OLED and neutral text white. It does not target `.a-icon-star` or `.a-icon-prime`, preserving orange stars and blue/orange Prime.

### 4. New large 402x283 grid product card (v7.470 VIEWPORT r1)
- `gridContainer`: white with a 1px light edge
- product title and price leaves: black
- product artwork: already correctly tamed (`brightness(0.42)`)
- 53x15 Prime artwork: incorrectly inherited the same `brightness(0.42)`, explaining the faded blue/orange appearance

v7.471 makes the structured grid floor OLED, makes title/price white, keeps the actual product image on TWB, and releases only the Prime image directly under `dealprice-stack` with `filter:none`. If Amazon serves this family as one full raster instead of the structured grid, these DOM floor/text rules do not match it; the inherited TWB lane simply tames the raster as requested.

## Book-details shadow

The v7.470 correction is retained: the actual visible white fade is the PUTB read-more `::before` owner, not the previously targeted `#productInfoTabExpanderHeader0 > .a-expander-content-fade`. The PUTB pseudo-element remains suppressed with no content/background/shadow.

## Validation

- `src/Tweak.xm`: **855,019 bytes**, below the frozen `<856000` gate by **981 bytes**.
- Production recurring-work counts: MutationObserver 0; `setInterval` 0; `requestAnimationFrame` 0; Web scroll listener 0; `createTreeWalker` 0.
- v7.471 isolated ad-card block: no `querySelectorAll`, no recurring traversal.
- Extracted v7.471 isolated-frame JavaScript: `node --check` PASS.
- Extracted v7.471 persistent CSS: 15 rules, `tinycss2` parse errors 0.
- `sh -n`: `ui-probe.sh`, `skeleton-probe.sh`, `validate.sh` PASS.
- `lint-logos`: PASS.
- Exact `scripts/validate.sh` historical-test normalization was reproduced, then all **148/148** Python regressions were executed in five bounded batches: 30/30, 30/30, 30/30, 30/30, 28/28 — PASS.
- Focused frozen/current chain also passes: v7.448 performance consolidation, v7.454 carousel ownership, v7.464 PDP ad/book contract, v7.467 strict anchors, v7.468 reconciliation, v7.469 user-style retirement, v7.470 isolated-frame ownership, and new v7.471 four-ad-card delivery.
- The monolithic strict runner was also started and passed its initial production/lint regression sequence; the sandbox command window terminated the sequential run before completion, which is why the same normalized corpus was then completed in bounded batches above.

FULL, VIEWPORT, and TRANSITION identities are regenerated as v7.471. The cross-frame probe now records `frameMeta.theme7471`; acceptance should additionally verify that the child frame itself lists `ad7470-pdp-isolated-theme` in its style inventory and that computed paints change, rather than relying on the source marker alone.
