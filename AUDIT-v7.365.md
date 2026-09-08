# AmazonDark v7.365 audit — probe-backed Cart same-day + Sustainability sheet

## Base

- Direct base: `7.364~universal-full-sweep-probes`.
- Parent `src/Tweak.xm` SHA-256: `d87a2f2ea16581da180850e6ff1ebe8e117e632253d81cecde273ec161a3b0e9`.
- Universal FULL/VIEWPORT scanner behavior is unchanged; operational filenames advance to v7.365 only.

## Probe-backed diagnosis

### Cart FULL probe — `AmazonDark-v7.364-ui-full-probe-20260908-081649-160-r3.txt`

1. `div.a-meter.p13n-same-day-bar-v2`
   - stock background: `rgb(255,255,255)`
   - radius: `8px`
   - this is the unfilled track plane
2. child `div.a-meter-bar`
   - authored background: `rgb(11,123,60)`
   - current state happened to fill the width, hiding the stock-white track visually
3. same-day text owners
   - `.p13n-same-day-info-text-before-price`: stock gray/dark
   - `.p13n-same-day-info-text-after-price`: stock gray/dark
   - `.p13n-same-day-amount-left-v2`: stock `rgb(15,17,17)`
   - `.p13n-same-day-threshold-price-v2`: stock `rgb(15,17,17)`
4. Saved item product-history metadata
   - bare `span.a-size-small`, privacy-safe hash `078d1d2f`
   - stock `rgb(15,17,17)`
5. Cart empty/removed state
   - `.sc-cart-header` captured stock-dark
   - `[id^=sc-list-item-removed-msg-text-]` / `.sc-undo-slide-content` captured stock-dark
   - `.sc-removed-msg-title` captured authored Amazon blue `rgb(33,98,161)`

### Product Search FULL probe — `AmazonDark-v7.364-ui-full-probe-20260908-082819-439-r1.txt`

The visible Sustainability AUI sheet was captured, not inferred:

- `h1.a-sheet-heading`, hash `b1c478e7` = visible sheet heading
- explanatory copy hash `42df94d7`
- certification heading hash `e99d3664`
- certification description hash `3959f5d6`
- `.a-sheet-web`: stock `rgb(255,255,255)` floor
- `.a-sheet-content-container`: stock `rgb(255,255,255)` floor
- `.s-pc-sticky-footer`: stock `rgb(255,255,255)` floor
- `.s-pc-bottom-sheet-carousel-inner`: stock `rgb(255,255,255)`, 1px `rgb(213,217,217)` border, 15px radius
- `.s-pc-program-name`: authored green parent `rgb(4,112,91)`

## v7.365 visual changes

- p13n same-day unfilled meter track -> OLED `#000`; `.a-meter-bar` is untouched.
- p13n same-day neutral copy/threshold-price lanes -> `#e8e6e3`.
- exact Saved-item bare history metadata lane -> `#e8e6e3`; success/link/price semantics remain excluded.
- empty Cart header + removed-message neutral copy -> `#e8e6e3`; embedded removed product title explicitly remains `rgb(33,98,161)`.
- Sustainability AUI sheet/content/heading/sticky-footer planes -> OLED `#000`.
- Sustainability certification cards -> OLED `#000` + 1px `#494d4d`; 15px stock radius preserved.
- Sustainability neutral copy -> `#e8e6e3`.
- no new filter/image rule in the Sustainability fix; green program ownership and explicit blue link ownership are preserved.

## Architecture / performance preservation

- No new MutationObserver.
- No new interval.
- No new RAF loop.
- No web scroll listener.
- No recurring hierarchy scan.
- No broad raster/image taming rule.
- No route-specific probe dispatcher.
- `src/AmazonDarkSB.xm`, `src/ADSkeletonProbe7339.js.inc`, `Makefile`, and `.github/workflows/build.yml` remain byte-identical to v7.364.

## Validation

See the handoff validation report. Full Theos/iOS SDK compile-link is unavailable in this runtime, so GitHub Actions/on-device Theos remains the authoritative package proof after push.
