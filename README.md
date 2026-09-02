# AmazonDark v7.267~xl-raster-divider-hero-backdrop-probe


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
