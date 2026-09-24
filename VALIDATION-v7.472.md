# AmazonDark v7.472 validation — PDP standalone-engine unification

## The discrepancy between working and failing standalone ads

The established working standalone-ad path is `ADStandalonePaintJS7104()`. It is not a single selector patch: it marks a confirmed standalone document, installs a constructable `CSSStyleSheet` into `document.adoptedStyleSheets`, preserves Prime/star/deal/badge semantics, applies the configured TWB media policy, classifies dominant full-raster creatives, and owns renderer/border chrome. Historical v7.97/v7.108/v7.114/v7.266 evidence shows this is the implementation behind the standalone families that already theme correctly.

The critical difference is an intentional route guard inside that mature engine:

`if(productish)return;`

`productish` is true for `/dp/`, product, and `/s` referrers. The four stubborn ads all live under the PDP/product child-frame path, so they were excluded from the mature engine and repeatedly fell into separate PDP-specific experiments. That is why adding more correct selectors did not make them behave like the working standalone ads.

## Why the recent attempts did not close the gap

- v7.440/v7.441 experimented with page-world child-frame styling but used a separate PDP stylesheet, not the mature standalone engine.
- v7.442/v7.443 tried private `_WKUserStyleSheet`; v7.444 deliberately returned to the earlier lineage with the same medium-ad/duplicate-border/compact-title defects still open.
- v7.464-v7.468 added accurate probe-derived selectors but kept a separate delivery lane.
- v7.469 returned to the private user-style idea.
- v7.470/v7.471 proved an isolated `WKContentWorld` could execute in the child renderer, but the resulting DOM/style route still did not produce device paint parity with the already-working standalone engine.

v7.472 therefore stops maintaining a second theming algorithm for these ads.

## v7.472 mechanism

`ADStandalonePaintJS7104()` is frozen byte-for-byte. Its source-region SHA-256 is:

`2734e76915bf577d60b9a012b6fee226035582aab2a499ee1c40e3a3130f7ebe`

At an existing finite PDP frame-owner event, native code now enumerates both WebKit frame APIs:

- `_frameTrees:` for site-isolated WebContent process trees;
- `_frames:` for the ordinary frame tree.

It evaluates in `WKContentWorld.pageWorld` via `evaluateJavaScript:inFrame:inContentWorld:completionHandler:`. A child frame must first prove an ad renderer (`#ad`, `#offsite-buy-box`, `#dynamic-bb`, renderer-factory, `gridContainer`, or `sp_hqp_phoneapp_shared`). Only that proven frame receives `data-ad7472-pdp-standalone`, after which a runtime copy of the unchanged mature standalone program bypasses only its historical product-referrer return.

The mature engine then creates its normal `data-ad7104-standalone` ownership and persistent adopted stylesheet. A small constructable v7.472 delta handles only the exact probe-known PDP variants:

- compact/offsite: OLED structural plate, light neutral brand/product copy, preserved Sponsored/rating semantics;
- 402x125 grid/Swiper: OLED grid/zinc/slide floors, square duplicate edge removed, one rounded gray inner edge retained, light neutral price/title copy;
- `sp_hqp_phoneapp_shared`: OLED AUI box/gradient plane and light neutral title/rating-count/price, with authored orange stars and blue/orange Prime sprite untouched;
- 402x283 structured card: OLED structure/light neutral title and price, product artwork still on TWB, exact Prime image released from brightness so its blue/orange artwork is restored.

If the qualifying large creative is actually a single raster, the unchanged mature dominant-raster classifier handles it as a raster instead of trying to recolor nonexistent internal text.

The v7.470 Book-details fix remains: the actual PUTB read-more `::before` gradient owner is suppressed rather than the unrelated AUI expander fade previously targeted.

## Probe acceptance criteria

The v7.472 child-frame probe exposes two independent receipts:

- `frameMeta.theme7472 == "1"` — the PDP promotion/delta reached the frame;
- `frameMeta.standalone7104 == "1"` — the same mature standalone engine used by working ads actually owns that child document.

A device capture should then show computed OLED structural floors, light neutral text, authored Prime/star/deal colors, the large-card Prime asset at unfiltered authored intensity, and the Book-details PUTB pseudo-element without bright gradient paint.

## Regression / performance validation

Final `src/Tweak.xm`: 855,183 bytes, under the frozen `< 856000` gate by 817 bytes.

The exact `scripts/validate.sh` v7.460 identity normalization was applied to the final test corpus and all 149 Python regressions were rerun in five bounded batches after the final dual-tree frame-delivery change:

- batch 1: 30/30 pass
- batch 2: 30/30 pass
- batch 3: 30/30 pass
- batch 4: 30/30 pass
- batch 5: 29/29 pass

Focused v7.440/v7.448/v7.454 and v7.464-v7.472 ownership/CI contracts also pass after normalization.

Static checks:

- `scripts/lint-logos.sh`: PASS
- `sh -n scripts/ui-probe.sh`: PASS
- `sh -n scripts/skeleton-probe.sh`: PASS
- `sh -n scripts/validate.sh`: PASS
- `MutationObserver`: 0 production call sites
- `setInterval`: 0
- `requestAnimationFrame`: 0
- Web `scroll` listeners: 0
- `createTreeWalker`: 0
- generic `querySelectorAll`: 1 (existing bounded path)

No recurring DOM scan, polling loop, RAF loop, or scroll-time theming machinery is added.
