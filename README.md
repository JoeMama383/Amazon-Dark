# AmazonDark v7.274~fast-product-probe

Direct production/video baseline: **optimized v7.270**.


## v7.274 compact product-scroll probe + SWV stage strip

- Keeps the v7.273 exact SWV/1m98b video overlay TWB owner unchanged.
- Darkens only the new SWV navigation strip (`8wyx7 > avw36`) from Amazon's translucent near-white plate to `#4a4f51`; its three authored button states/dividers remain untouched.
- Replaces the oversized product-scroll forensic dump with a compact explicit-trigger current-view inventory for `8wyx7`, `1m98b`, and `avw36`. No cross-frame dump, no hit grid, no recurring runtime work.


## v7.274 compact product-scroll probe + SWV stage strip

- Keeps the v7.273 exact SWV/1m98b video overlay TWB owner.
- Darkens only the SWV navigation strip (`8wyx7 > avw36`) from Amazon's translucent near-white plate to `#4a4f51`; its three button states and authored divider pseudo-elements are left untouched.
- Replaces the oversized product-scroll forensic dump with a compact explicit-trigger current-view inventory for `8wyx7`, `1m98b`, and `avw36`. No cross-frame dump, hit grid, scrolling, observer, timer, RAF, or recurring scan.

## v7.273 exact SWV video repair

- Probe-confirmed current untamed Search-results video is a distinct host family: `_mediaSection_8wyx7_` / `_videoPlayerContainer_8wyx7_` / `_videoWrapper_8wyx7_` containing the reused `_videoContainer_1m98b_` player.
- The captured video leaf is filter-free and the sibling `_videoOverlay_1m98b_` plane is transparent. The captured page does not expose the older `template=FEATURED_ASINS_VIDEO_LIST` host used by the v7.270 rule.
- All v7.271/v7.272 video-selector broadening is removed. The complete v7.270 ADTWBJS video behavior is restored first.
- One exact new TWB selector is added: only an `_videoOverlay_1m98b_` directly inside the `8wyx7` video-player/wrapper path receives the configured TWB shade. The VIDEO compositor remains filter-free and controls remain authored by Amazon.
- Retains the non-video Search magnifier restoration and exact neighboring-button gray divider correction.
- Retains the explicit-trigger product shopping/scrolling probe behind the existing probe dispatcher. No second screenshot observer or SIGUSR2 source is added.
- No MutationObserver, interval, RAF loop, web scroll listener, or recurring production scan is added.

---

# AmazonDark v7.272 — Product-scroll video parity + restored Search-results probe

- Direct base: v7.271 optimized regression repair.
- Restores the historically proven Search `single-video-card` / Video.js (`video.vjs-tech` + `.vjs-poster`) media family to the `/s` TWB lane using the existing configured TWB factor.
- Matches the product-scroll vertical ribbon divider to the adjacent control borders exactly (`#747a7c`).
- Re-adds a dedicated `/s` product shopping/scrolling forensic probe. It is routed through the existing screenshot/SIGUSR2 dispatcher, performs no scrolling, and adds no second listener/signal source or recurring runtime work.
- Home / Person / Cart / Menu / Alexa probes remain retained.

# AmazonDark v7.271~search-video-chrome-regression-fix

Direct base: **v7.270~optimized-exact-probes**.

## Regression repair

- Restores the product-results Search magnifier by retaining both live exact native renderers: `SBSearchBarIconView` in `SBSearchBarLeadingStackView`, plus the bounded leading-image slot under `SBSearchField` / `SBMultilineSearchView`.
- Restores Search sponsored-video TWB without filtering the playback compositor directly: `_c2Itd_videoOverlay_*` and the exact `template=FEATURED_ASINS_VIDEO_LIST` `_videoOverlay_*` roles are now matched independently of transient CSS-module hash suffixes.
- Recolors the exact `sf-rib30-dropdown-main-container` left divider under the Search bar to the standard AmazonDark gray `#494d4d`.
- Retains the optimized v7.270 event-driven architecture and all five dormant probes; no observer, timer, RAF loop, web scroll listener, or recurring scanner is added.

---

# AmazonDark v7.270~optimized-exact-probes

## v7.270 maximal optimization sweep

- Preserves the v7.270 visual contract and all five explicit probes (Home, Person, Cart, Hamburger, Alexa/Rufus).
- Removes the dead Hamburger helper and collapses the three exact footer action IDs behind one predicate. The first-open footer repair now rejects every non-footer RCTView before any Menu ancestry/classification work.
- Makes Search delivery ownership singular: the current probe-proven `GlowIngressView` is authoritative; the old `ANXSubNavContainer` and `nav_packard_bar` alternate owners and their generic `UIView` hot-path checks are removed.
- Makes the main Search magnifier exact to `SBSearchBarIconView` inside `SBSearchBarLeadingStackView`; the old geometry/field alternate path is removed.
- Narrows compact standalone media TWB to the current probe-proven `#dynamic-bb [data-acei-id=prod-img]` lane and removes the broad compact media sweep plus the legacy `lfstyl-img` lane.
- Keeps the active Highlights wrapper-only TWB path but promotes it to an exact owner (recent Person probes still show this renderer). No visual behavior is dropped there.
- Centralizes native TWB overlay creation/update and gives Menu `subtheme_image_*` one exact overlay path instead of a generic-pass-plus-secondary path.
- Person section headings now use only the current probe-proven final text-renderer geometry; the nested `*ttl` alternate hydration path is removed.
- Probe dispatch uses only current native tab IDs: `home`, `meTab`, `cartTab`, `menuTab`, `rufusTab`. No probe is removed.
- Retires the old generic React “bright card near text” heuristic. Person, Hamburger, location, AppCX sheets, and savings sheets now rely on their exact surface owners instead of a seven-ancestor size/color claim on ordinary React text updates.
- Positive Person/Hamburger surface classifications are cached on the view until normal React move/reuse invalidation, avoiding repeat root walks on stable views.
- Hamburger raster classification now rejects every non-`RCTUIImageViewAnimated` leaf before Menu-root/ancestor work; the current Menu probe shows these are the actual raster leaves for featured programs and expanded subthemes.
- Footer IDs are compared directly with no temporary lowercased string allocation.
- Production remains event-driven: no MutationObserver, interval, RAF loop, web scroll listener, polling loop, or recurring hierarchy scan.

## v7.270 hamburger footer first-paint repair + retained Alexa/Rufus comprehensive probe

- Fixes the Menu first-open race where `Switch Accounts`, `Sign Out`, and `Customer Service` can show stock white inner surfaces until leaving and re-entering the tab.
- Bad/good probe diff shows the exact 406x48.7 footer surfaces are present in both states. In the bad first render their UIKit paint is still white/uncommitted; in the good re-entry they are OLED black with the intended single gray edge and r16.
- Root cause is lifecycle ordering: the footer parent can run its paint hook before the identifying `account_switcher` / `so` / `cs` descendant exists, so it is not classified as the footer surface on that pass. A later re-entry/layout supplies the missing pass, explaining why the second state is correct.
- v7.270 uses the already-hooked lifecycle of those three exact action leaves to re-own only their local footer ancestors as soon as the hierarchy is complete. No observer, timer, polling, scroll hook, or document scan is added.
- Keeps the v7.269 outer standalone-ad border de-duplication and the comprehensive Alexa/Rufus probe unchanged.

- Fixes the newly introduced double-border regression on structured 414x125 standalone Home ads. The v7.268 Home probe shows the top-level `ape_gateway_dynamic-…_mshop_placement` is 430x129.8 and carries a 1px `#3b4043` edge, while the child `modern-414x125-layout-container` independently carries the correct rounded 1px `#3b4043` edge. The outer APE edge is therefore duplicate renderer chrome.
- Removes only that top-level structured 414x125 APE placement border/outline/shadow. The child renderer border remains unchanged and is the sole visible ad frame. Full-raster borderless handling, medium/XL divider removal, Sponsored feedback, TWB, and compact-price parity are retained.
- GitHub history review found v7.162 (`54a8764`) as the clearest earlier Alexa/Rufus paint reference: Search Rufus surfaces were explicitly owned OLED black with gray borders, and the `nice-widget-container-inline-slot` Alexa surface required both its normal background and `::before`/`::after` painters to be neutralized. That evidence is used to shape the new probe, but this build does not guess at or change the current Alexa-tab visuals yet.
- Adds an Alexa/Rufus probe gated to the selected native `ANXTabBarButton#rufusTab`. It scores every visible WKWebView for Rufus/Alexa/assistant/conversation/chat/Nile signatures, inventories stylesheet owners and AmazonDark injected owners, performs finite viewport snapshots plus a final full DOM inventory, recurses through open shadow roots/accessibly reachable iframes, and records computed text/fill/background/image/mask/border/radius/outline/shadow/font/SVG/filter/transform/pseudo-element/media state.
- The same Alexa trigger also inventories native UIKit/React ownership: all native scroll candidates, complete view ancestry/geometry, backgrounds/tints/layer borders, sublayer samples including shapes/gradients, RCT border properties, attributed-text runs, controls, image/TWB state, and a finite top-to-bottom native scroll walk. WebKit/native offsets and `scrollEnabled` are restored after capture.
- The Alexa probe records no visible strings, accessibility-label text, aria-label/alt/value contents, URLs, or network payloads; it retains technical identifiers and privacy-safe text lengths/hashes only.
- No MutationObserver, interval, RAF loop, web scroll listener, or recurring hierarchy scan is added. All probe work remains screenshot/SIGUSR2-only.

## v7.268 compact standalone current-price text parity

- Fixes the compact structured/non-full-raster standalone ad current price painting stock dark on the OLED card.
- The v7.267 Home probe proves this compact renderer uses `#dynamic-bb` and an exact `data-acei-id="prc"` current-price lane rather than the medium/large `data-testid="price-container"` contract.
- Only `#symbolOne`, `#price-integer`, and `#price-fraction` directly under that `prc` lane are forced to the normal light neutral text.
- The authored discount percentage remains red, and the struck-through list-price metadata remains secondary gray. Product title, images, Sponsored chrome, borders, and raster/full-raster classifiers are unchanged.
- Retains both v7.267 fixes: XL full-raster divider removal and OLED-black Home hero backdrop planes.
- No MutationObserver, timer, RAF loop, scroll listener, or recurring scan is added.


## v7.267 XL full-raster divider + Home hero backdrop OLED lock

- Fixes the XL/300x250-style standalone full-raster white strip captured in the v7.266 Home probe. The probe proves it is the same authored `DIV.border-enforcement` chrome (`430x2`, `1px solid #ccc`) seen on the medium raster case, but this XL renderer lives directly in the main Home document rather than a standalone child frame.
- Adds a narrow Home-only structural selector for `creative-container` instances with a direct `IMG.ad-background-image.mrc-btr-creative`, hiding only their `.border-enforcement` (plus pseudo-elements). No raster pixels, TWB strength, Sponsored feedback, or structured product-ad borders are changed.
- Locks both Home hero-derived backdrop planes — `#wd-backdrop-overscroll` and probe-confirmed `#wd-color-image-backdrop` — to OLED black. Actual hero images/video/cards remain untouched.
- Retains all v7.266 fixes, including medium full-raster divider removal, structured standalone gray border parity, one-shot full-raster parent proof, and repaired Home current-frame probe.
- No MutationObserver, interval, RAF loop, scroll listener, automated scrolling, or recurring full-document scan is added.

## v7.266 Home standalone border parity + full-raster divider + hero overscroll + Home probe repair

- Restores the established gray edge on structured/non-full-raster 414x125 standalone ads. v7.265 removed the broad medium placement rule while making raster ads frameless, which allowed Amazon's stock white renderer border to show again.
- Keeps every structurally-proven full-raster standalone ad frameless at every size. A full-raster child sends a one-shot proof message to its exact parent iframe/APE placement so outer parent chrome is cleared without guessing from size.
- Hardens the medium full-raster separator repair: `.border-enforcement` is hidden, its pseudo-elements are suppressed, and the proven full-raster child clears renderer/container borders using inline `!important` ownership.
- Locks the dedicated Home `#wd-backdrop-overscroll` plane to OLED black, so pulling past the top cannot expose the active hero card's average campaign color. The normal `#wd-color-image-backdrop` and hero artwork remain Amazon-owned.
- Repairs the v7.265 narrow Home probe regression. `removeAllUserScripts` cleared the actual script but v7.265 left the probe association set, so the bridge was not re-added and captures returned `bridge-missing` / `collector-missing`. v7.266 resets that association and self-heals the main-frame bridge at explicit trigger time.
- No MutationObserver, interval, RAF loop, scroll listener, automated scrolling, or full Home-document scan is added.

## v7.265 Person refresh text + borderless full-raster + narrow Home probe

- Keeps v7.263's Person refresh/remount image recovery and v7.264's standalone raster taming.
- Fixes Your Orders card headers after Refresh/Retry. Historical Person evidence identifies the exact leaf as `RCTTextView#ImageWithTextViewTextComponent` under `yo_btn` / `YoAsinCarouselItem*`; v7.265 reasserts only that lane at final draw so the delivery-date header cannot revert to stock dark text during React rehydration.
- Full-raster standalone ads are frameless at every size. The previous `.ape-placement.is-image-oo` outline is removed; the historical `.border-enforcement` 430x2 medium strip has its actual border removed, not merely recolored; dominant-raster child frames also clear renderer/container chrome. Structured Swiper/product-card borders are retained because those are not full-raster creatives.
- Adds a Home current-frame probe: no scrolling and no full-document DOM inventory. It records only native views intersecting the current screen plus DOM branches intersecting the current viewport, and requests the same bounded snapshot from child frames.
- All probes remain screenshot/SIGUSR2-only. The Home all-frame bridge is dormant except for a probe request and performs no normal-runtime scanning.

## v7.262 Hamburger footer inner-surface parity

- The v7.261 Menu probe proved the three footer actions are nested: a 410x52.7 outer border wrapper contains a 406x48.7 React surface, which contains the 404x46.7 action leaf.
- The visible white fill and stock teal edge belong to the 406x48.7 middle surface. v7.262 makes that exact surface OLED black with the standard #494d4d 1pt/r16 treatment.
- The 410x52.7 wrapper and 404x46.7 action leaf are transparent/no-border so they cannot create duplicate edges or square fills.
- Text/glyph behavior remains the same as the surrounding Menu cards; no SVG/RNSVG taming behavior changed.


## v7.263 Person refresh image re-tame

- Probe-backed root cause: refreshed Buy Again product raster leaves are `ANXFastImageView` nodes at depth 31 below the Person `RCTScrollView#me` root. The old Person classifier stopped after 24 ancestors, so refreshed leaves fell out of Person scope, were marked media-blocked, and lost TWB.
- Extends only the finite Person ancestor budget from 24 to 48. This remains lifecycle/event driven; no observer, timer, recurring hierarchy scan, web scroll listener, or global React sweep is added.
- Clears the cached React-surface classification when image views receive a new image or move between window/superview owners, including the `RCTUIImageViewAnimated` override path. This prevents recycled refresh leaves from inheriting stale non-Person scope.
- Leaves the TWB strength, media eligibility rules, authored-image exclusions, Person text/glyph fixes, Cart fixes, and v7.262 Hamburger footer ownership unchanged.
