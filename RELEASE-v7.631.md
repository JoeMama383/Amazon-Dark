# AmazonDark v7.631 — Search/PDP input-lag optimization

This is a **real production performance patch**, not only a probe update. On Search and Product Details routes, the three isolated checkout programs do not install CSS/listeners. The largest is an ~84-KB authored checkout-only stylesheet containing 107 `:has()` selectors that have no owners in Search/PDP. The historical checkout payloads and their exact visual/CSS hashes are unchanged on checkout-related routes. This removes redundant style-matching/invalidation during scroll/hydration on two problematic menus.

The separate advertising-feedback module no longer runs a layout-forcing full-body `innerText` scan during Search/PDP `DOMContentLoaded` or `pageshow`. Its original click-triggered visible-text owner remains intact, including for ad feedback opened from these pages.

The explicitly armed performance recorder now pulls document navigation, frame, scroll and input aggregates through the proven `evaluateJavaScript` result channel every five seconds (also while the page is loading) because the asynchronous message bridge has failed repeatedly. It reports `webPeriodicSamples` and `webPeriodicFailures` for honest coverage. The original 7.630 capture gave Search DOM interactive 6.76 s; PDP DOM interactive 15.64 s. Use those as the before timings, with the important caveat that Amazon page/server variation can affect a single capture.

**Unverified until device run:** whether this reduces full perceived lag, by how much; the other ~400+ relational CSS patterns in the core/medical modules may still require attention. The full iOS compile is performed by GitHub Actions, not locally here.
