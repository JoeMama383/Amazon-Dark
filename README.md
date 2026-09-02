# AmazonDark v7.265~person-refresh-ordertext-raster-borderless-homeframe-probes

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
