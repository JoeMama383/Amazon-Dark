# AmazonDark v7.409 audit

## Scope

Direct parent: `v7.408~permission-location-switcher-hardening`.

This release is intentionally narrow and probe-backed. It corrects the three visible defects left by the v7.408 Camera/Microphone/Choose-your-location implementation without changing the v7.408 inactive app-switcher invariant or v7.407 PDP skeleton owner.

## Camera permission sheet

The v7.406 FULL r1 probe identifies the two exact button roots as `inflight-prompt-dismiss-button` and `inflight-prompt-allow-button`, and the 24x24 checkbox descendant under `allow-all-CAMERA`.

v7.409 changes ownership as follows:

- button label descendants get a dedicated exact ancestor gate and are forced to AmazonDark light text at React assignment, storage mutation and final draw;
- the existing React border remains the sole border owner and is rewritten to `#747a7c` at 1pt with the authored 8pt radius;
- the competing CALayer border introduced by v7.408 is removed;
- the 24x24 camera opt-in checkbox is explicitly excluded from floor/border ownership so its authored fill, edge and state are preserved.

## Microphone permission sheet

The v7.406 FULL r2 probe identifies `actionButton` as the Continue button. The same single-owner border path applies: React border = 1pt gray, radius = 8pt, no added CALayer ring. Its neutral label is forced light. The exact microphone artwork handling from v7.408 is unchanged.

## Choose-your-location side rails

The v7.406 FULL r4 probe records the exact visual cause:

- outer bright RCTView: 430 x 375.7, clipped, lower-sheet geometry;
- inset RCTScrollView: 394 x 375.7, already dark;
- the 18pt left/right difference exposes the white outer shell as two vertical rails.

v7.408 required the historical address-card root marker before this outer shell could be claimed. That left a timing hole. v7.409 keeps the marker path but adds an exact local structural witness: full-width bright clipped shell + one local child tree containing a dark RCTScrollView at ~89–94% of shell width and matching height. This is event-driven through the existing RCTView lifecycle/background hooks; no recurring scan is introduced.

## Preservation

Preserved unchanged:

- blue permission/settings/location links;
- orange selected-address edge;
- camera checkbox authored state;
- microphone artwork;
- v7.408 inactive neutral app-switcher protection and restore behavior;
- v7.407 exact PDP `IESSkeletonView` transition owner;
- existing FULL / VIEWPORT / TRANSITION architecture.

No new MutationObserver, timer, requestAnimationFrame loop, Web scroll listener, polling loop, recurring hierarchy scan or WKUserScript family was added.
