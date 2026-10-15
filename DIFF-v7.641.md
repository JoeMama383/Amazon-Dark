# v7.641 — reduce CSS loaded on Search and product pages

Base: complete v7.640 source. The latest ordinary v7.640 capture still shows long WebKit input delays while Search/product documents are being constructed. This release changes production CSS loading; it does not add another runtime probe.

## Evidence and interpretation

The 30.9-second normal capture contained no style-cost experiment or overlapping diagnostic session and reported no dropped records or injection errors. Search had 23 input samples, mean input-to-next-RAF 577.3 ms, maximum 1,298 ms, and DOM interactive at 11,099 ms. Product had 38 samples, mean 555.0 ms, maximum 2,875 ms, and DOM interactive at 8,670 ms. Their measured theme-install totals were 54 ms and 31 ms respectively. Main native React theme callbacks were below 0.5 ms. Native event dispatch reached 97.9 ms, so it was not uniformly free, but it did not account for the multi-second WebKit gaps.

Deferred CSS/rendering remains a supported hypothesis, not a proven exclusive cause. Cheap JavaScript installation does not include WebKit's later selector matching, style invalidation, layout and painting. The captured Search/product documents still contained 898/1,026 top-level theme rules, including rules for unrelated complete menus.

## Production changes

- Extend the existing pure-source route filter for main-frame `/s`, `/s/...`, `/dp`, `/dp/...`, `/gp/product/...` and `/gp/aw/d/...` documents. Omit complete rules whose entire top-level selector list requires an explicitly unrelated full-page owner, including Orders, checkout thank-you, Live, Cart, Addresses, Pharmacy and dedicated account/service screens.
- Leave four dedicated sheets empty on these hot routes: Returns, address management, checkout thank-you, and Live/thank-you completion. They contain only full-page-specific rules, including Returns' nested media rules. The authored sources remain available on their own routes.
- Preserve mixed selectors, at-rules in other sheets, similar-but-different owner prefixes, universal specificity gates, unknown routes and child frames. Shared add-to-cart, shipping, reviews, lists, sharing and map overlays retain their rules. No layout dimensions or authored CSS declarations change.
- Retain v7.640's detached-style recovery at DOMContentLoaded, load and pageshow, including same-ID replacement handling. No polling, DOM walker, MutationObserver or delayed repaint is added.
- Keep the existing taming factor, OLED surfaces, neutral text/border scheme and semantic colors. This release removes irrelevant rules before installation rather than disabling theming after the page has loaded.

The local production-payload fixture installs 188,848 CSS characters on Search, down from 262,563 (28% less), and 221,224 on product, down from 316,287 (30% less). Fixture rule counts change from 897 to 694 and 1,025 to 732. These counts are not an estimate of latency reduction.

## Offline diagnostic change

`scripts/performance-report.py` now shows per-document route, rule inventory, input sample count, mean/max input-to-RAF, event-loop lag and DOM-interactive time. It correlates independent timing IDs only when both sides have a unique time origin within WebKit's five-millisecond rounding tolerance. Ambiguous child-frame/WebView matches are omitted; missing timings stay `n/a`. Cumulative snapshots are not counted repeatedly. This analysis runs outside the app; normal `arm` and `export` commands are unchanged apart from version identity.

## Scope and remaining verification

This filtering assumes the existing full-document Search/product route lifecycle. Unknown pages and child frames receive the complete source. If Amazon moves a dedicated full-page menu into a same-document Search/product route, that newly embedded owner will need review. Existing shared overlay coverage is deliberately retained.

The ZIP contains source for GitHub Actions. A linked installable package, actual cold-start paint, carousel interaction and on-device latency are not verified by local syntax or fixture tests. Use a normal performance capture after installing the Actions package; `arm styles` deliberately forces recalculation and is unsuitable for ordinary responsiveness measurement.
