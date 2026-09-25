# AmazonDark v7.488 validation

## Scope

Direct parent: `v7.487~book-transition-signout-v6185`.

This build is a probe-backed Returns correction. No launch, transition, Sign Out, PDP, probe transport, or general runtime architecture is intentionally changed.

## Probe evidence

### ORC return-request warning

The supplied v7.486 FULL capture identifies the exact warning owner as:

- `.a-box.a-alert.a-alert-warning`: 396×116 pt, radius 8 pt;
- computed border widths: 2 px top/right/bottom and 12 px left;
- authored border color: `rgb(228,121,17)`;
- inner `.a-box-inner.a-alert-container`: zero border width.

The prior Returns sheet also added an AmazonDark `inset 4px` orange shadow to the inner container. That was a second visual line, not Amazon geometry. v7.488 removes the explicit AmazonDark orange border-color and inset-shadow ownership entirely. Only the warning floor remains OLED. Amazon therefore owns the original warning border color, widths, radius, and alignment.

### Your Returns history / recommendations

The supplied FULL capture identifies:

- `.returns-history-section` / `#returnsHistorySection`;
- `.returns-history-header-section` and inherited neutral wrappers still carrying `rgb(15,17,17)` on OLED;
- `.recommendations-section.instrumentation`;
- `.recommendation-horizontal-section` and its AUI carousel.

v7.488 extends neutral white-copy ownership to the Returns history section while excluding links, prices, and semantic status colors. Recommendation CTA button paint is changed to OLED + gray border color + white text. No width, height, border radius, padding, positioning, or other button geometry is assigned.

## Static / syntax checks

- `scripts/lint-logos.sh`: PASS.
- `sh -n scripts/ui-probe.sh`: PASS.
- `sh -n scripts/skeleton-probe.sh`: PASS.
- `sh -n scripts/validate.sh`: PASS.
- decoded `src/ADReturnsTheme7480.js.inc`: `node --check` PASS.
- `src/ADReturnsTheme7480.js.inc` adjacent C literals: C99 syntax PASS.
- same include: GNU++98 syntax PASS.
- `tests/test_v7488_returns_geometry_headers_cta.py`: PASS.
- `src/Tweak.xm`: 854,553 bytes, below the frozen 856,000-byte gate.

## Normalized regression checks

The exact `scripts/validate.sh` current-version normalization was applied to a temporary test copy. The following high-risk/current regression contracts were run and passed:

- probe embedding + C/C++ probe payload compilation;
- FULL/VIEWPORT/TRANSITION handoff identity;
- the v7.484 CI-failure regression `test_v7363_search_related_cart_claimed.py`;
- v7.465–v7.478 CI/PDP compatibility tests selected around the current handoff;
- Returns email theme;
- v7.479 Objective-C++ build-syntax guard;
- Returns-menu completion;
- PUTB immersive/review/profile theming;
- the older Returns follow-up contract, updated only to require authored warning geometry rather than an AmazonDark-redrawn orange line;
- PUTB overlay-fade removal;
- v7.487 AMI transition + exact v6.0.185 Sign Out port;
- v7.488 Returns geometry/header/CTA regression.

The monolithic strict validator was also started. It progressed through the established v7.377-era regression sequence without a failure before this container's execution timeout. This report does **not** claim an uninterrupted 165/165 monolithic run.

## Runtime mechanism audit

The v7.488 change is declarative CSS only. It adds no:

- `MutationObserver`;
- polling/timer loop;
- `requestAnimationFrame` loop;
- web scroll listener;
- recurring hierarchy scan.

## Expected device result

1. The return-request warning keeps Amazon's original orange border color and exact geometry; the extra inset/orange line is gone.
2. Returns-history headers/termination copy are white on OLED.
3. Recommendation Buy Now/Add-to-Cart-style AUI primary CTAs use OLED fill, gray border color, and white text while keeping Amazon's geometry.
4. Existing authored blue links/review counts, orange stars, prices, and image taming remain intact.
