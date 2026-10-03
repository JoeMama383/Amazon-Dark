# AmazonDark v7.559 validation

Evidence base:

- completed `AmazonDark-v7.556-ui-full-probe-20261003-132520-246-r1` from the exact order-item screen;
- captured route is `section#pop.layout__background` with order cards `div.pop-card.js-pop-card`, row controls `a.a-touch-link.a-box`, chevrons `i.a-icon.a-icon-touch-link`, and quantity badge `span.item-view__qty-large`;
- quantity badge measured 30x30 with 15px radius and stock 1px border; v7.559 does not write width, height, position, transform, margin, radius, or font-size.

Static contracts:

- route/family ownership is gated by `section#pop.layout__background:has(.item-view__qty-large)`;
- all `pop-card` structural floors on that captured route are OLED black with neutral gray separators/borders;
- primary text becomes light, secondary text remains legible gray, and authored link/price/status/Prime/star/rating/badge/deal colors retain their current color;
- captured touch rows are OLED with gray borders, light text, and dark pressed state;
- captured border-painted chevrons become light without geometry changes;
- `item-view__qty-large` becomes medium gray with white text and gray border, using flex alignment to center the numeral while preserving the authored circle geometry;
- exact product image under `.item-view__inner-col > a.a-link-normal` receives configured TWB, excluding the separate Share icon;
- v7.558 Filters and universal FULL/VIEWPORT routing remain intact;
- Account production coloring remains deferred until a real Account capture exists;
- no MutationObserver, recurring timer, RAF, scroll listener, polling loop, or production traversal is added.

Final verification (2026-10-03):

- exact `scripts/validate.sh` historical identity normalization was reproduced across all `tests/test_*.py` tests;
- 213/213 normalized regression tests passed against the final v7.559 source in four independent chunks (55 + 55 + 55 + 48), with zero failures/timeouts;
- the normalized v7.369 core-hash/isolated-checkout contract passes;
- the normalized v7.448 performance-consolidation contract passes;
- the normalized v7.467 strict PDP/consolidation contract passes;
- the normalized v7.558 Filters + universal FULL/VIEWPORT + no-speculative-Account-paint contract passes;
- `tests/test_v7559_order_item_oled_count_geometry.py` passes;
- `scripts/lint-logos.sh` passes;
- `scripts/ui-probe.sh`, `scripts/skeleton-probe.sh`, and `layout/DEBIAN/postinst` pass shell syntax checks;
- v7.559 adds no MutationObserver, interval, RAF, scroll listener, setTimeout lane, or `dispatch_after` lane in the new order-item owner.
