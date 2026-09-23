# AmazonDark v7.470 — isolated-frame ownership for stubborn PDP ads

This release stops iterating on selectors in delivery paths that the device probes already proved were absent from the failing renderer documents.

## Lineage audit

The relevant PDP standalone-ad lineage spans at least 38 versioned builds from v7.431 through v7.469 (431, 432, 433, 435–469). Not every build changed these exact bugs, but the same standalone-ad title/floor/border family was repeatedly carried, diagnosed, or revisited. Earlier standalone-border work predates this lineage as well.

The history is consistent:

- v7.431 themed the parent APE shells.
- v7.432 added an all-frame child stylesheet.
- v7.433 explicitly concluded that the remaining standalone-ad failure could not be diagnosed from the parent shell and introduced the cross-frame probe.
- v7.439 still failed on-device; the issue was identified as frame ownership/delivery rather than selector discovery.
- v7.440 moved to WebKit frame-tree/page-world evaluation.
- v7.442/v7.443 tried private `_WKUserStyleSheet` all-frame delivery.
- v7.444 deliberately returned to the v7.440 lineage; the medium-ad interior, duplicate border, and compact title remained open.
- v7.452/v7.453 still list standalone-ad floors/extra borders and compact ad title/glyph as outstanding.
- v7.454 found the exact `gridContainer -> gridRegion -> grid-inset-carousel -> swiper-slide -> gridRegionCarousel` child renderer and deliberately excluded its already-correct arrows/media.
- v7.464–v7.468 used correct probe-derived selectors but kept an ineffective child-delivery route while CI contracts were repaired.
- v7.469 repeated the earlier private user-style approach. That route is retired here rather than being treated as a new solution.

## What the v7.463 probes actually prove

The failing child ad documents successfully execute the universal cross-frame probe in the named `AmazonDarkUIProbe7453` isolated `WKContentWorld`. In those same documents the production ad-theme markers/styles are absent.

That gives v7.470 a proven transport instead of another inferred one: a separate production `WKUserScript` is installed at document start, for all frames, in the exact named isolated content world already demonstrated by the probe.

The script installs a persistent exact stylesheet and also applies inline `!important` ownership to the measured leaves at finite lifecycle boundaries (`DOMContentLoaded`, `readystatechange`, `load`, `pageshow`). There is no MutationObserver, interval, RAF loop, scroll listener, polling loop, or recurring document walk.

## Exact fixes

### Compact/top standalone ad

The r1 child probe measured `brand-name` and `product-description` as black-on-black while `combined-brand-and-description` was already light. v7.470 owns those exact leaves (and descendants) with white text in the proven isolated child world. The next cross-frame probe reports `frameMeta.theme7470=1` so delivery is directly verifiable.

### Medium / half-carousel standalone ad

The r2 child probe measured `gridContainer` as a 402×125 white square with a 1px light border, plus white/zinc internal floors. v7.470 makes the exact neutral shells OLED, removes the square outer/slide edges, retains the rounded `gridRegionCarousel` as the single gray inner border, and makes only the measured price/currency leaves light. Arrow controls, CTA colors, and media remain untouched.

The r3 main probe measured `#ape_detail_btf_mshop_placement` as the separate square 1px outer border around a child ad that already had its own inner rounded treatment. v7.470 explicitly zeros that main-frame placement border without selecting the child's rounded layout container.

### Book details white shadow and dark labels

The r1 probe identifies the actual white shadow as the `::before` pseudo-element on `.putb-read-more-primary-view` / `putb-read-more-primary-view-...-product-details-card_primary-view`. Its computed `background-image` is a gradient. Earlier builds targeted the unrelated `#productInfoTabExpanderHeader0 > .a-expander-content-fade`, which is why the Book details shadow survived.

v7.470 suppresses the exact PUTB read-more pseudo-element and makes the measured `.a-size-small` labels and `.a-text-bold` values light. This is installed in the already-working main-document PDP stylesheet; it does not depend on child-frame delivery.

## Probe acceptance

A v7.470 VIEWPORT capture should prove, rather than infer:

- child `frameMeta.theme7470` is `1`;
- child style inventory includes `ad7470-pdp-isolated-theme`;
- compact `brand-name` / `product-description` compute light;
- `gridContainer` computes black with 0px outer border;
- `gridRegionCarousel` retains one gray rounded inner edge;
- the BTF main placement computes 0px border;
- Book-details PUTB `::before` has no generated gradient paint and its labels/values compute light.

FULL, VIEWPORT, and TRANSITION probe identities are regenerated for v7.470.
