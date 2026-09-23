# AmazonDark v7.470 validation — isolated-frame ownership

## Why this is not another selector-only build

The relevant standalone-ad lineage is substantially longer than v7.464–v7.469. The current repository artifacts show the same family being carried, diagnosed, or revisited across at least 38 versioned builds from v7.431 through v7.469. Earlier standalone-border work predates that lineage.

The key historical mistake was repeatedly treating a delivery failure as a selector failure. v7.433 explicitly introduced the cross-frame probe because parent-shell evidence was insufficient. v7.440 moved to frame-tree/page-world evaluation. v7.442/v7.443 tried private `_WKUserStyleSheet` all-frame delivery. v7.444 deliberately reverted to the v7.440 lineage with the medium ad interior, duplicate border, and compact title still unresolved. v7.452/v7.453 continued to list those defects as open. v7.454 then identified the exact grid-carousel child renderer. v7.469 repeated the private user-style route; v7.470 removes it.

## Probe-derived root causes

### Compact/top standalone ad — r1

`AmazonDark-v7.463-ui-viewport-probe-20260923-114703-307-r1.tar` shows the child renderer at 430×74. `brand-name` and `product-description` compute `rgb(0,0,0)` on the dark ad floor, while `combined-brand-and-description` is already light. The child style inventory contains only one anonymous Amazon style sheet (8 rules): no `ad7454`, `ad7458`, or `ad7440` production-theme sheet is present.

### Half-carousel standalone ad — r2

`AmazonDark-v7.463-ui-viewport-probe-20260923-120708-452-r2.tar` shows the child `gridContainer` at 402×125 with white background and a 1px `rgb(204,204,204)` square edge. The inner `gridRegionCarousel` has a 4px radius and 1px light edge; this is the border that should survive as the single gray rounded edge. The measured `price`, `price-text`, and `currency` leaves are stock dark. The child style inventory again contains only Amazon styles (877-rule link, 91-rule link, one tiny anonymous style) and no AmazonDark theme style.

### Duplicate BTF outer border — r3

`AmazonDark-v7.463-ui-viewport-probe-20260923-121324-647-r1.tar` shows `#ape_detail_btf_mshop_placement` at 402×125 with a 1px `rgb(73,77,77)` radius-0 border. Its iframe is inset to 400×123 with no border. This proves the visible duplicate square edge is the main-frame placement, separate from the child's rounded card edge.

### Book details white shadow — r1

The actual white fade was previously misidentified. The r1 main-document probe shows:

- `#product-details-card_primary-view .putb-main-text` computing black;
- the exact read-more owner `putb-read-more-primary-view-CONTENT_EVALUATION_BLOCK-product-details-card_primary-view`;
- that owner's `::before` has `content:""`, a 344.39×30px pseudo-element, and `background-image: gradient`.

The earlier `#productInfoTabExpanderHeader0 > .a-expander-content-fade` rule is a different expander family and therefore could not remove this Book-details gradient.

## v7.470 mechanism

The universal cross-frame probe already proves that an all-frame document-start `WKUserScript` in the named `AmazonDarkUIProbe7453` isolated `WKContentWorld` executes inside the failing cross-origin renderer documents. v7.470 adds a separate production script through that exact proven transport:

- document start;
- `forMainFrameOnly:NO`;
- `inContentWorld:ADUIProbeWorld7453()`;
- exact selectors only;
- persistent `ad7470-pdp-isolated-theme` stylesheet;
- inline `style.setProperty(..., 'important')` pins for the measured child nodes;
- finite lifecycle reassertion on `DOMContentLoaded`, `readystatechange`, `load`, and `pageshow`;
- no MutationObserver, interval, RAF loop, Web scroll listener, polling loop, or recurring document traversal.

The failed v7.469 `_WKUserStyleSheet` path is removed entirely.

The main-document Book-details fix is placed in the already-working `ADPDPProbeBackedFixesJS7458` path and targets the exact PUTB pseudo-element plus the measured label/value classes.

The next cross-frame probe now emits `frameMeta.theme7470`; a value of `1`, together with style ID `ad7470-pdp-isolated-theme`, directly proves the production theme reached that renderer frame.

## Validation

Final production source size:

- `src/Tweak.xm`: **855,109 bytes**
- hard gate: `< 856,000`
- headroom: **891 bytes**
- production `querySelectorAll(` call sites: **1**, preserving the v7.448 gate

Exact validator normalization was applied to the complete source regression tree. All **147/147** Python regressions passed in three bounded batches (50 + 50 + 47), including:

- frozen v7.439 PDP UI completion contract;
- frozen v7.440 frame ownership contract;
- v7.448 performance consolidation contract;
- v7.454 carousel exclusions/order contract;
- v7.464–v7.469 compatibility/CI contracts updated to reject the failed private user-style lane;
- new `test_v7470_pdp_isolated_frame_ownership.py`.

Additional checks:

- `scripts/lint-logos.sh`: PASS
- `sh -n scripts/ui-probe.sh`: PASS
- `sh -n scripts/skeleton-probe.sh`: PASS
- `sh -n scripts/validate.sh`: PASS
- extracted v7.470 isolated production JavaScript: `node --check` PASS
- executable isolated-world DOM fixture: PASS (marker, style install, compact title pin, grid outer floor/edge, rounded inner border)
- forbidden production recurring mechanisms in the new block: none
- `_WKUserStyleSheet` / `_addUserStyleSheet:` current source path: absent

The one-shot local `AD_STRICT_VALIDATE=1 sh scripts/validate.sh` exceeds this tool's individual execution window because the historical corpus is large; the same normalized regression files were therefore executed completely in bounded batches. GitHub Actions remains the compile/link/package proof for the iOS/Theos target.
