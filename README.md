# AmazonDark v7.175~remaining-fixes-dynamic-probe

## v7.175 remaining fixes

- Fully release Home visual-subnav category chips (including Luxury / See all) from AmazonDark ownership, including generic label/button/tint/TWB/border paths.
- Pre-paint exact 414x125 Home and Search APE standalone creatives with TWB from stable placement IDs; Sponsored feedback remains outside the filter and the placement keeps the standard gray border.
- Preserve the now-working Search Amazon Haul treatment: OLED floors, white copy, existing TWB product imagery, stock emoji/stars, and standard OLED/gray Add-to-cart buttons.
- Claimed coupon state: white Saving copy, black check-circle background, white check mark.
- Retain the v7.173+ dynamic multi-interface probe: one unique file per screenshot/SIGUSR2 trigger, 28 MiB cap per capture.

No active MutationObserver, recurring timer, RAF loop, or scroll listener is introduced by these fixes.

---

# AmazonDark v7.174~four-surface-fixes-dynamic-probe

## v7.174 probe-classified fixes

- Release the exact native Home visual-subnav controller so Amazon category chips keep authored stock styling.
- Tame exact Home `.ape-placement.is-image-oo` 414x125 full-raster iframe; use the standardized gray ad border; Sponsored feedback stays outside the filter.
- Theme exact Search `template=PROMPTS_BENEFITS_CAROUSEL` / `spt-benefits-carousel-*` floors OLED black with white generic text; preserve `spt-benefit-chip-sparkle` blue raster.
- Theme exact Search `.s-promotion-highlight-color` Save-% span transparent with `#008000` text; Limited-time-deal remains separate.
- Retain v7.173 multi-file dynamic probe architecture: every screenshot/SIGUSR2 writes a unique capture, 28 MiB max per file.

# AmazonDark v7.173~dynamic-multi-interface-probe

Direct base: **v7.172~smart-refinements-targeted-probe**.

## v7.173 classified fix + probe rebuild

- Preserves the probe-proven More-to-explore repair from v7.172: only `a.smart-refinement-pill[role=button]` inside `.smart-refinements-content` gets the established `#4a4f51` fill / `#34383a` pill border / white text treatment; the exact `.smart-refinements-content` top and bottom dividers use standard border gray `#494d4d`.
- Does **not** add new speculative styling for the still-unclassified Save-% plate, medium raster standalone ad, or Brands-related media. Those are intentionally left for fresh v7.173 captures.
- Rebuilds diagnostics as a route-independent, screenshot/SIGUSR2-triggered dynamic truth probe. It inventories visible computed backgrounds, pseudo-element paint, borders, buttons/controls, semantic ad/badge/savings/pill/feature/brand surfaces, all visible IMG/PICTURE/SVG/VIDEO/CANVAS media, hit-test stacks, native visible view paint, and child/cross-origin frame truth.
- Every trigger writes a **new uniquely timestamped probe file** instead of deleting/overwriting the previous capture. Multiple screenshots across different interfaces can therefore be exported and uploaded from the same build without losing earlier runs.
- Each probe file is independently hard-capped at **28 MiB**, below the requested 30 MB ceiling. Main-frame and all-frame payloads are individually bounded so one pathological frame cannot consume the entire file before other diagnostics land.
- The probe remains dormant during normal use: no MutationObserver, interval, RAF loop, scroll listener, or recurring whole-document scan is added.

## v7.173 probe filenames

Each screenshot/SIGUSR2 capture writes a file matching:

`AmazonDark-v7.173-dynamic-probe-YYYYMMDD-HHMMSS-SSS-rN.txt`

This eliminates stale same-name export collisions and allows several interface captures per build.

---

## Historical base: AmazonDark v7.172~smart-refinements-targeted-probe
Direct base: **v7.171~search-regression-restore-probe**.

## v7.172 targeted More-to-explore repair

- Probe-proven current pill: `a.smart-refinement-pill[role=button]` inside `.smart-refinements-content`.
- Retires v7.170/v7.171 broad `.s-widget-container` button fallback entirely; unrelated Search/video controls are no longer in this lane.
- Exact current pills: `#4a4f51` fill, `#34383a` existing outline/border color, white copy; Amazon geometry/radius remains untouched.
- Exact `.smart-refinements-content` existing top/bottom divider colors become standard neutral `#494d4d`; widths/styles are not changed.
- Existing v7.169 Nile/Rufus pill lane remains for the alternate renderer.
- All v7.171 launch/location/TWB/video-control restoration and v7.170 standalone/full-raster work is preserved.
- Screenshot/SIGUSR2 probe remains reset-per-capture with 28 MiB ceiling and now adds a dedicated `smartRefinements` inventory with directional border paint.
- Probe-only `greenSavingsSurfaces` scan records any visible green-painted surface by computed color, plus ancestry/children, so the still-unresolved lime savings plate can be identified without guessing its class.

---

# AmazonDark v7.171~search-regression-restore-probe

Direct base: **v7.170~launch-search-full-raster-probe**.

## v7.171 regression restoration

- Restores the Search delivery/location strip to OLED black without weakening the v7.170 launch-cover gate. The exact `GlowIngressView` owner no longer depends on primary-controller classification timing; it remains gated by exact class, normal window level, full-width compact geometry and the existing light pin/text path.
- Restores v7.169 Brands-related `_bXVsd` raster/logo TWB. v7.170's broad multi-brand preservation rule was clearing `filter` on every IMG/PICTURE and therefore outranking the dedicated TWB selectors. Only SVG/icon/star/sparkle artwork is now released from filtering.
- Restores v7.169 sponsored-video controls. The v7.170 generic non-product AUI-button fallback is excluded from video/play/pause/mute subtrees, allowing the existing stock-control isolation/transparent control-shell rules to remain authoritative.
- Keeps the v7.170 launch readiness fix, Search savings/pill/carousel floors, medium Search standalone ownership and compact full-raster TWB classifier.
- Probe remains screenshot + SIGUSR2, resets per capture, and retains the 28 MiB ceiling.

---

# AmazonDark v7.170~launch-search-full-raster-probe

Direct base: **v7.169~search-carousel-pills-standalone-badge-probe**.

## v7.170 launch/Search/full-raster repair

- Launch cover: restores the proven bounded pre-v7.115 readiness gate. The cover is not released merely because native splash controllers disappear; a visible Amazon Web root must be interactive/complete, populated with media, effectively OLED-dark, stable for three 125 ms checks, and survive a final 250 ms dwell. The check is launch-only, capped at 64 attempts, and falls back to the existing SpringBoard hold rather than exposing stock white.
- Prime Savings: replaces the stale exact `_bGlmZ` hash selectors with prefix-stable `couponSns` / `couponBadge` family ownership. Plate/pseudos are transparent and copy is coupon green `#008000`; Limited-time-deal remains separate.
- More to explore: adds the actual AUI base-button-in-carousel lane while retaining the existing Nile lane. Fill `#4a4f51`, border `#34383a`, text white; geometry is untouched.
- Explore key features: owns the hash-rotating `_bXVsd_multiBrandContainer_` family plus its one/two outer structural shells as OLED black, generic copy white, Sponsored copy/glyph subdued, while authored blue sparkle/icon/SVG/media art remains untouched.
- Search APE Sponsored feedback: the main-frame feedback sibling is explicitly OLED black with the existing subdued Sponsored text/info-glyph contract.
- Home complete-raster standalone TWB: restores the proven v7.144 bounded dominant-raster classifier inside standalone child frames. Structured product ads are rejected; only a >=76% width / >=60% height / >=56% area raster or CSS-background leaf is tamed. No observer, interval, RAF, scroll listener, or recurring scan is introduced.
- Probe: screenshot + SIGUSR2, reset per capture, 28 MiB hard ceiling; Search inventories are prefix-stable and the all-frame Home/Search ad dump may use up to 5 MB so cross-origin raster ownership is no longer starved.


Direct base: **v7.168~badge-container-fix-probe**.

## v7.169 Search polish

- Prime Savings: pins the actual bright-lime renderer rather than guessing another AUI badge path. The live plate color is Amazon's `#7fda69` and its exact class family is `._bGlmZ_couponBadge_vDASk` inside `._bGlmZ_couponSns_1QLVK` / `._bGlmZ_couponSns_-u_8b`. That exact plate/pseudos become transparent and its copy uses coupon green `#008000`. Existing AUI success/savings coverage remains as a separate fallback; Limited-time-deal, status badges, and coupon tiles are untouched.
- More to explore: themes all three established Nile pill shells (`.nile-ingress-pill-button`, `.nile-inline-pill-button`, `.nile-inline-ingress-pill-button`) with the already-established header/Rufus pill scheme: `#4a4f51` fill, `#34383a` border, white text. No geometry changes.
- Explore key features: owns the exact `_bXVsd_multiBrandContainer_1cmb8` carousel family captured in v7.162. Structural floors become OLED black and generic copy white; blue star/sparkle/icon/SVG art and media remain Amazon-owned; Sponsored copy/glyph use the existing subdued `#b1aaa0` contract.
- Search medium standalone: extends the proven `renderer-factory-ad-container -> modern-414x125-layout-container` standalone contract to product/search-referrer child frames by renderer identity, including the root/main-content/content/layout, primary/secondary text, and Sponsored feedback row. This reuses the Home medium-ad OLED/text/border treatment without width/height/padding/radius/flex/position changes.
- Probe remains screenshot/SIGUSR2 triggered, resets each run, and remains hard-capped at 5 MiB. The existing bounded all-frame bridge is sampled once after 0.55 s so a visible cross-origin 414x125 Search ad child can report its renderer shell/paint; that sub-dump is separately truncated at 900,000 characters.
- No MutationObserver, interval, RAF, scroll listener or recurring DOM scan is added.

Direct visual base: **v7.164~swatch-options-bounded-probe**.

## Swatch cleanup

The v7.165-v7.167 special-case work that attempted to restore the one blank/black
swatch has been discarded. Stock Amazon renders that same odd-man-out swatch as
blank OLED black, so it is not an AmazonDark defect. The v7.164 correction that
stopped AmazonDark from flattening *all* normal authored color swatches remains.

## Search micro-badge fixes

- Exact current white attribute-chip renderer: `.s-background-color-platinum`.
  Its stock `rgb(240,242,242)` floor and light border are removed; the chip is
  transparent and its text becomes Amazon yellow `#ffd814`.
- Limited-time-deal is deliberately excluded from this lane. Existing
  `DEAL_*` / `data-a-badge-type=deal` handling is unchanged.
- Savings/Prime Savings uses the historical anonymous AUI badge structure that
  can wrap `.a-color-success` / saving / savings descendants. The complete
  anonymous badge and its label/inner label are now transparent, while the text
  uses `#008000`, matching the current AmazonDark coupon-container green.
- Coupon boxes themselves remain `#008000` with white text.

## Probe

The screenshot/SIGUSR2 probe is now a narrow **visible badge truth** capture.
It records only visible Search product cards containing platinum attribute chips,
savings/success badges, explicit deal comparison elements, or coupon comparison
elements. It does not record element text. The file resets every run and is hard
capped at 5 MiB.

No MutationObserver, interval, RAF, scroll listener, or recurring scan is added.

# AmazonDark v7.164~swatch-options-bounded-probe

Direct base: v7.163~product-card-polish-probe.

## Product-card corrections

- Restores Amazon-authored color swatches. The v7.163 descendant-wide `.puis-variations-block :is(a,span,div)` OLED rule is removed because it flattened `.s-color-swatch-inner-circle-fill` artwork to black.
- Ports the previously proven exact variation/swatch shell ownership: variation/link/list-view shells, `.s-color-swatch-container`, and `.s-color-swatch-outer-circle` are transparent with background-image/shadow cleared, while the inner color fill is never recolored.
- Themes product-card action-stack buttons, including `See options`, exactly like the established Add-to-cart treatment: OLED black, neutral `#747a7c` border/inset edge, light text, and no compositor filter.
- Keeps v7.163 Best Seller white text, transparent true-green savings text, and true-green coupon boxes.

## Bounded probe

- Probe output is reset at the start of every manual/screenshot capture instead of accumulating runs indefinitely.
- Hard file cap is 28 MiB, safely below the requested 30 MB ceiling.
- Search DOM JSON is capped at 2.2M characters per evaluated WebView and the all-frame bridge at 0.9M characters.
- Variation diagnostics now inventory the exact swatch structures rather than every `a/span/div` descendant.
- No MutationObserver, interval, RAF, scroll listener, or recurring scan was added.

## v7.163 product-card result polish

- Direct base: v7.162. Preserves the working v7.159/v7.161 Search-transition behavior and the three route-exclusive styling/TWB lanes.
- The exact `.puis-variations-block` family seen under the product photos is OLED black, including its small structural descendants; its existing text color is left alone.
- Every primary button inside `.puis-card-container` receives the same OLED-black + gray-border paint already used by the correct `.puis-atcb-button`, so yellow and dark Add to cart variants converge without geometry changes.
- Text under `.puis-status-badge-container` is forced true white while Amazon keeps the badge fill/shape.
- Savings/saving/success labels inside product cards lose colored floors and use true-green `#00c853` text on transparent backgrounds.
- The custom coupon tile fill changes from muted sage `#405a4a` to true green `#008000`; white coupon copy is preserved.
- Screenshot/SIGUSR2 diagnostics stay enabled and now inventory variation strips, all product-card primary buttons, status-badge descendants, and savings candidates.
- No MutationObserver, timer, interval, RAF loop, scroll listener, or recurring repair scan is added.

# AmazonDark v7.162~search-scrollbar-alexa-carousel-twb-probe

## v7.162 Search scrollbar + Alexa strip + standalone-carousel TWB probe

- Direct base: v7.161. Preserves every working v7.159/v7.161 Search transition and three-lane stylesheet fix.
- Makes the `/s` product-feed WebKit scrollbar thumb light (`#d5d9d9`, hover `#e8e6e3`) instead of the dark thumb introduced by the split stylesheet.
- Removes the light gradient/white strip from `nice-widget-container-inline-slot` (the Researched-by-Alexa inline slot) by owning its background and pseudo-painters as OLED black/transparent.
- Tames the exact standalone-carousel company-logo raster `img._bXVsd_image_iVomf`.
- Tames the exact standalone-carousel product/lifestyle raster `img._bXVsd_lifestyleImage_1fluW`.
- Explicitly leaves the 1x1 tracking pixel `_bXVsd_pixel_3yBgA` alone.
- Retains the screenshot/SIGUSR2 diagnostics and adds dedicated `alexaStrip` and `standaloneCarouselMedia` inventories.
- Adds no MutationObserver, interval, RAF loop, scroll listener, or recurring repair scan.

# AmazonDark v7.161~search-seasonal-scrollbar-probe

## v7.161 search seasonal + scrollbar probe

- Preserves the v7.159 three-lane Search/transition behavior that fixed the reopen floor.
- Restores a light WebKit scrollbar thumb in the `/s` product-feed lane.
- Tames `img.s-entity-pd-carousel-tile-element-image` in the seasonal autocomplete carousel.
- Paints the seasonal tile title/description container OLED black with light text.
- Keeps v7.160 `_c2Itd_image_3UiYm` company-logo + product-carousel TWB.
- Reintroduces the screenshot/SIGUSR2 diagnostics and adds a dedicated `seasonalAutocomplete` inventory.


Built directly from v7.158. Restores the exact v7.149 Search/autocomplete CSS behavior inside the route-exclusive /autocomplete lane and restores v7.149 transition-wrapper layout-time ownership for the proven Search keyboard-gap underlay. Keeps the fast three-lane architecture. Fixes the scx-stt image wrapper to OLED black and applies TWB to the exact _c2Itd theme-collection product carousel images while excluding the brand-logo image that shares the same raster class. Diagnostic probe retained for verification only.

# AmazonDark v7.158~search-floor-scx-fix-probe

Direct base: v7.157. Keeps the three route-exclusive stylesheet/TWB architecture. Restores the proven v7.133 Search-gap transition-backing mechanism at exact Autocomplete WebView mount, normalizes autocomplete row separators back to #494d4d, and restores direct brightness TWB on exact `img.scx-stt-image` sticky-refinement rasters. Diagnostic probes remain enabled temporarily.

# AmazonDark v7.157~three-lane-stylesheet-probe

Performance architecture: three route-exclusive WebKit style lanes. The Home/menu document receives only the menu sheet; the dedicated `/autocomplete` WebView receives only the Search-pane sheet; `/s` receives only the product-scrolling sheet. The same split is applied to TWB. This build retains the v7.156 diagnostic probes temporarily while UI parity is verified.

# AmazonDark v7.156~search-regression-fix-probe — fast Search regression repair + diagnostics

## v7.156 delta (direct base: v7.155)

- Preserves the v7.154/v7.155 fast Search architecture rather than restoring the old cross-surface Search stylesheet.
- Restores the Researched-by-Alexa/Rufus header floor with cheap direct structural ownership.
- Restores the Search-focus/autocomplete floor to OLED black.
- Restores expanded filter footer controls to the established medium gray.
- Makes exact deal-badge text white after Natural/sx-cloud ownership.
- Keeps the white two-cards control shell while forcing only its inner glyph black.
- Reintroduces the screenshot/SIGUSR2 UI diagnostics and all-frame bridge for this temporary probe build only.

# AmazonDark v7.155~zero-delay-search-compile-fix

Direct base: v7.153~production-performance-hotpath-fix.

## Priority
Production performance is the primary design constraint. Search theming must be achieved with static, narrowly scoped ownership and must not add live DOM walkers, MutationObservers, timers, RAF loops, screenshot probes, or broad selectors that force every Search element/image to participate in expensive style matching.

## v7.154 zero-delay Search hot-path rewrite

- Adds a dedicated `/s` fast stylesheet: Search no longer parses or matches the cross-surface Home/PDP/cart theme. The Search sheet is ~19 KB, has **0 `:has()`**, **0 `:where()`**, and only two class-substring matches, while retaining the Search/video/coupon/Haul/Rufus/badge fixes through exact owners.
- Adds a dedicated Search TWB sheet of only four rules. Search no longer participates in the large Home/standalone media selector graph.
- Main cross-surface CSS removes the duplicated Search block entirely, shrinking `Tweak.xm` below the v7.146/v7.149 source size despite the newer UI fixes.
- Generic `UIView` floor hooks immediately bypass WebKit internal views; exact WKWebView/WKScrollView/WKContentView owners handle those surfaces without running UIKit heuristics over the compositing tree.
- Removes the remaining broad Search DOM selector lanes that made every recycled result node/image evaluate substring and long `:not(...)` chains.
- Replaces Search TWB's generic `#search img` matcher with positive product/media classes and uses compositor-cheap opacity on Search raster media over OLED black instead of CSS brightness filters.
- Removes Search `:has()` selectors from the live result/ribbon paths.
- Moves bottom-tab repaint interception from every `UIControl` interaction to `ANXTabBarButton` only.
- Removes the generic native delivery-band heuristic from the all-`UIView` background hot path; exact `GlowIngressView`/ANX subnav owners remain.
- Replaces delivery-band ancestor walks with one-time associated-object descendant marks.
- Removes `WKContentView` per-layout floor rewrites and converts large transition-wrapper floor rescans from `layoutSubviews` to `didAddSubview`/lifecycle events.
- Preserves v7.153 Search/ad/badge/video fixes and ships no diagnostic probe.


## Post-v7.149 UI parity gate

The Search fast-path rewrite retains the UI fixes added after v7.149 without restoring the expensive generic selector graph:

- v7.150 Nile ingress pills remain medium gray (`#4a4f51`) with white text.
- Crazy-good-finds / Haul non-image card chrome remains OLED black.
- Coupon tile + price segment remain muted sage (`#405a4a`) with white text.
- Search video compositor remains unfiltered; stock play/mute controls are not custom-painted by AmazonDark.
- VIDEO_SINGLE_PRODUCT cards retain the standardized `#494d4d` border and OLED product-detail floors.
- Alternate `_c2Itd_*` standalone-video cards retain the standardized gray border/OLED floors, video-overlay TWB, and direct product-raster TWB.
- `_c2Itd_image_pQREQ` keeps the v7.152 visibility/stacking repair so the lower-left product image can render.
- Natural / `sx-cloud` attribute badges remain transparent with yellow text.
- savings/success text remains transparent green; Limited Time Deal remains a red plate with white text.
- Rufus/Nile inline pills, Add-to-cart outlines, Sponsored/ad-feedback gray chrome, Search ribbon/dropdowns, and the More-like-this wrapper fixes remain present.

No diagnostic probe ships in v7.155.


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


## v7.155 compile-only correction

- Cast `ANXTabBarButton` to `UIView *` before checking `window`, avoiding private forward-class property errors.
- Correct Objective-C escaping for the existing Privacy JavaScript regexes. Runtime regex semantics are unchanged.
- No Search-theme, TWB, ad-card, badge, video, or performance-path behavior was intentionally changed from v7.154.
