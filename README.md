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
