# AmazonDark v7.473 validation — standalone survivor sheet

## Decisive v7.472 probe result

The supplied `AmazonDark-v7.472-ui-viewport-probe-20260923-221404-693-r1.tar` finally proves the remaining large standalone-ad failure is **not frame delivery**:

- child frame is 402x283 and classifies as `adRoot=true`;
- `frameMeta.standalone7104="1"` — the mature working standalone engine is already executing in this exact failing frame;
- `frameMeta.theme7472=""` — the separate v7.472 promotion path did not own it;
- `gridContainer` still computes `rgb(255,255,255)` with a 1px `rgb(204,204,204)` edge;
- `productTitle` computes `rgb(17,17,17)`;
- price/currency compute `rgb(15,17,17)`;
- product art is correctly TWB-tamed at `brightness(0.42)`;
- the 53x15 Prime image is also incorrectly `brightness(0.42)`, which explains the washed-out orange check / blue Prime treatment.

This resolves the earlier ambiguity: the established standalone implementation is present, but its historical CSS selectors do not cover these newer PDP renderer families.

The probe also exposed a diagnostic blind spot. Its style inventory only enumerated DOM `<style>` and `<link rel=stylesheet>` nodes, while the mature standalone engine persists its working stylesheet through `document.adoptedStyleSheets`. Absence from the old `styles[]` list therefore was not proof that the standalone stylesheet was absent.

## v7.473 mechanism

`ADStandalonePaintJS7104()` is left byte-for-byte frozen. SHA-256 of its regression-locked source region remains:

`2734e76915bf577d60b9a012b6fee226035582aab2a499ee1c40e3a3130f7ebe`

Instead, the already-all-frame `ADPDPGridCarouselFix7454()` program in the **same `ADCoreWebJS7271()` WKUserScript as the mature standalone engine** is upgraded from a transient DOM `<style>` node to a constructable survivor sheet:

- one `CSSStyleSheet` per child window;
- `replaceSync()` once;
- append to `document.adoptedStyleSheets`;
- `data-ad7473-survivor=1` only after successful adoption;
- finite `pageshow` re-ownership if Amazon replaces the adopted-sheet list;
- no DOM-hydration gate and no requirement for a target node to exist at injection time.

The ineffective v7.472 `ADPDPStandalonePromoteJS7472()` copy/promotion path is removed. The inherited v7.448 frame bridge is returned to its original `ADForcedPDPFrameThemeJS7440()` payload instead of carrying another standalone fork.

## Exact four-family coverage

1. **Top compact/offsite renderer**
   - the v7.463 r1 probe's actual 414x51 `rgb(248,248,248)` plate is the direct first child of `renderer-factory-ad-container` when that renderer contains `#offsite-buy-box`;
   - that exact plate becomes OLED, keeps a gray edge, loses its `mix-blend-mode:multiply` paint interaction;
   - only measured neutral brand/product leaves become white;
   - Sponsored/info semantics remain separately scoped.

2. **Odd 402x125 grid/Swiper renderer**
   - grid/zinc/white-slide floors become OLED;
   - a `gridContainer:has(.swiper-wrapper)` loses the square outer edge;
   - the rounded `gridRegionCarousel` retains one standard gray edge;
   - neutral price/currency text becomes white;
   - arrows and product media are untouched.

3. **AUI `sp_hqp_phoneapp_shared` medium renderer**
   - A-box and authored inner gradient become OLED;
   - measured title, rating-count and price copy become white;
   - no `.a-icon-star` or `.a-icon-prime` repaint/filter is introduced.

4. **402x283 structured grid renderer**
   - non-Swiper grid gets OLED floor and one gray outer edge;
   - product title/price become white;
   - existing TWB on product artwork remains unchanged;
   - only the exact `dealprice-stack > img.inline-block` Prime artwork is released from TWB.

The existing full-raster/TWB machinery remains unchanged for raster creatives.

## Book-details shadow

The actual v7.463 r1 owner remains fixed from v7.470 onward:

- `#product-details-card_primary-view .putb-read-more-primary-view::before`
- `[id^=putb-read-more-primary-view-][id$=-product-details-card_primary-view]::before`

The generated gradient pseudo is removed with `content:none`, `display:none`, `background:none`, and `box-shadow:none`.

## VIEWPORT probe expansion

The v7.473 cross-frame probe now records:

- `frameMeta.survivor7473` from `data-ad7473-survivor`;
- `document.adoptedStyleSheets` inventory;
- adopted sheet rule count, bounded CSS hash, and a `survivor7473` signature flag;
- existing computed node paint and `standalone7104` marker.

This means the next device capture can separately prove: core script reached the frame, constructable survivor sheet was adopted, and computed paint changed.

## Regression/static validation

- `src/Tweak.xm`: **852,804 bytes**, 3,196 bytes below the frozen 856,000-byte gate.
- `src/ADUniversalUIProbe7362.inc`: 82,051 bytes, below the 95,000-byte gate.
- `src/AmazonDarkSB.xm`: 19,169 bytes, below the 19,200-byte gate.
- Survivor JavaScript: `node --check` — PASS.
- Survivor CSS: 16 parsed rules, zero tinycss2 parse errors — PASS.
- Shell syntax: `ui-probe.sh`, `skeleton-probe.sh`, `validate.sh` — PASS.
- `scripts/lint-logos.sh` — PASS.
- Production recurring-work counts: MutationObserver 0; setInterval 0; requestAnimationFrame 0; Web scroll listeners 0; TreeWalker 0; generic querySelectorAll remains 1.
- Logos structure: 81 `%hook` + 2 `%hookf` = 83 `%end` — balanced.
- Exact normalized repository Python regression corpus: **150/150 PASS** in six bounded 25-test batches using the same v7.460→current identity normalization as `scripts/validate.sh`.
- Frozen v7.448 performance consolidation and v7.454 carousel-scope regressions pass.
- v7.462 and v7.464–v7.473 focused handoff regressions pass.

The repository's sequential validator exceeds this environment's single-command execution window, so the same normalized corpus was executed completely in bounded batches rather than truncating the validation run.
