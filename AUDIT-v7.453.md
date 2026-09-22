# AmazonDark v7.453 — isolated probe transport and guarded document walks

Parent: v7.452-probe-recovery. This is a source handoff, not a compiled or device-verified package.

## Evidence

The supplied v7.451 110848 r4 TAR is the search menu: 13 scroll positions, then scroll-move-failed before final inventory. It does not contain the screenshot's product image.
The newer v7.452 114915 r4 product TAR was also inspected: PDP_STREAM_START_ERROR result=pdp-stream-bridge-unavailable, zero DOM payloads, and two native hierarchy dumps. The DOM scan never started. File size is not evidence of document coverage.
An older v7.440 product capture identifies the image as #newerVersionFeature .nevaMobImage img, with filter:none. That exact leaf receives the existing white-taming preference factor. Links, stars, red price and green stock copy are not filtered.

## Changes

- Handler registration, all-frame document-start listener, and every UI-probe JavaScript evaluation use the same named isolated WKContentWorld. The page-world handler was unavailable even after reattachment in v7.452; this removes dependence on that page context. The precise reason for Amazon's unavailable page-world handler is not proven by the trace.
- Every WebView gets mounted-DOM streaming inventory before a guarded root/vertical-overflow walk, with bounded viewport evidence at every step and streaming inventory afterward. Product routing no longer suppresses the Web document walk.
- A fixed-height document can use an eligible inner vertical scroll container discovered by the inventory. Horizontal carousels are not mistaken for the vertical document owner.
- Writes use scrollLeft/scrollTop in the isolated context. Detached roots, backgrounding, and height collapse terminate with partial coverage rather than repeated moves.
- Scroll positions restore once at the end, not between root/owner/inventory phases. Collapsed or detached owners are not jumped into. No second native WebKit offset correction or forced layout.
- End-of-walk coverage reports owners that grew beyond the visited extent. Deadline, transport, owner and frame failures remain partial.
- Removed the duplicate full native hierarchy scan at completion. Initial native evidence remains. PDP still avoids a second native scroll driver; native-only menus retain the cooperative native walk.
- Full, viewport and transition identities are v7.453, with separate plain TAR exports. The source distribution ZIP does not change probe archive format.

## Limits and validation

128 runnable Python regression entry points passed. New executable JS cases cover product/search walks, fixed-height inner owners, horizontal exclusion, growth accounting, single restoration, backgrounding, collapse and detachment. Existing streaming tests cover offscreen nodes, bridge absence, finite yielding and deadline termination.
AD_STRICT_VALIDATE=1 sh scripts/validate.sh was attempted and stops at test_v7385_sponsored_c_linkage.py because this workspace lacks clang. Three clang-dependent test entry points could not run here. No Theos/iOS compilation or phone test was performed. CI and device validation remain required; elimination of black flashes/freezes is not claimed.
Child frames and unmounted/virtualized content are best-effort; the final full inventory describes mounted content and bounded samples preserve intermediate visible evidence. This is finite opt-in diagnostics, not production polling or a guarantee of all possible app content.

## Outstanding UI backlog

This build changes only the verified newer-model image theme. Medium standalone ad floors/extra borders, compact ad title/info glyph, large raster/video ads, missing Customers also bought imagery, product transition skeleton, $59.97 ad carousel, color-variant floors, and Similar brands borders remain pending device/probe verification. It does not claim those fixed.

## Phone workflow

Copy the source folder contents into /var/mobile/Amazon-Dark-phone, preserve the executable postinst bit, run strict validation, commit and push manually. Install the resulting CI package and relaunch Amazon before probing.

FULL: take one screenshot in Amazon and leave it active while the walk runs. Then return to NewTerm and run sh scripts/ui-probe.sh status followed by sh scripts/ui-probe.sh export full.

VIEWPORT: run sh scripts/ui-probe.sh arm, open Amazon to the target scene, then return to NewTerm and run sh scripts/ui-probe.sh export viewport. The last foreground scene is captured at the background boundary.

TRANSITION: run sh scripts/skeleton-probe.sh arm transition, reproduce the transition, then run sh scripts/skeleton-probe.sh export.
