# AmazonDark v7.391 UI completion re-audit

## Base
- Direct parent: `7.390~checkout-ui-completion`.
- Re-reviewed all eight Sep. 10 v7.389 FULL captures against the actual v7.390 selectors and the existing checkout neutral-text contract.
- v7.389 Subscribe-sheet and exact checkout-only teal app-switcher suppression remain unchanged.

## Residual misses found in v7.390
1. **Help page heading** — the visible top `h1` is `article.help-content > h1`, outside `#csg-support-topics`; v7.390 correctly handled the topic-card rows and `All Help Topics`, but not this one heading. v7.391 adds only that heading to the light-neutral text owner.
2. **Maple banner direct text** — both the checkout Prime Business Card block and the `#cruise` payment cross-sell put meaningful neutral copy directly in `.maple-banner__text`. v7.390 recolored child `span/strong/b` nodes but did not give the container itself light text, so direct text could remain black. v7.391 makes the exact text container light while the `.a-color-link` child remains authored blue.
3. **Delivery-address divider finish** — the FULL probe shows two `.shipping-address-select-card-divider .a-divider-inner::after` painters retaining a stock gradient, plus the bottom `.a-divider-break > h5` keeping a white background around `or`. v7.391 removes that gradient, keeps the divider `#747a7c`, paints the `or` backing OLED, and normalizes the break-line edge to `#747a7c`.

## Re-checked v7.390 targets
- Help topic row floors, row dividers, outer borders and chevrons: covered.
- Subscribe loader blocker and exact 100x100 spinner raster: covered.
- Lower-carbon portal sheet/content/text: covered; existing close/lightbox retained.
- Gift-options two AUI card floors, textarea/sender border ownership, Continue button and checkbox/art exclusions: covered.
- Checkout Prime Business Card white owners and user-controlled TWB image lane: covered; direct-text gap fixed here.
- Select a Payment Method semantic selected/unselected/loan/gift-card/claim-code/footer owners: covered; selected Amazon blue border and switch/art painters preserved. `#cruise` iframe floors are covered; direct-text gap fixed here.
- Delivery-address deck/cards/accordion/button/radio/link owners: covered; divider residual fixed here.
- Subscribe recurrence popover floors/text/gray row dividers/close icon: covered; active Amazon blue selection border remains authored.

## Architecture
- The v7.391 visual changes are declarative additions/strengthenings inside the existing checkout document-start stylesheet.
- No MutationObserver, interval, RAF loop, Web scroll listener, polling loop, recurring hierarchy scan, extra WKUserScript, fake control, or generic app-switcher painter is introduced.
- No generated React `css-*` class is used as a new ownership selector.

## Device status
- Local audit validates source and probe coverage, not Amazon's final composited render. Device confirmation remains required.
