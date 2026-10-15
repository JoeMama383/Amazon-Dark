# v7.642 — review ownership caching

## Problem and evidence

The normal v7.641 capture still has initial input-to-frame gaps up to 784 ms on Search and 1422 ms on the product page. Those are better than v7.640's 1298 and 2875 ms, but not acceptable as the final experience. Theme installation itself takes only about 24–26 ms; that does not measure the subsequent CSS matching and rendering work during page construction. Native theme hooks are below 0.5 ms in this capture, with no child-frame repair round trips.

Controlled local stylesheet isolation identified the retained review sheet as additional rendering work even before a review container exists. It repeatedly uses `body:has(...)` ownership checks across its rules. This candidate removes that repeated relational matching from that sheet on the two affected main-document route families. It does not claim that CSS is the only remaining source of phone stalls.

## Production change

- Keep all review declarations and descendant selectors. Replace the repeated review ownership disjunction and the standalone-mobile-review condition with a cached body attribute.
- Preserve selector specificity with `:is()` and a zero-specificity `:where()` condition. Retain the distinct mobile-review and product-root states.
- Install one observer only when the review sheet is installed on a main Search/PDP route. Observe child-list changes and ID changes; inspect two review IDs and, only when a review owner exists, the product ID. No descendant traversal, computed styles, layout reads, timer, per-node processing or attribute write when state is unchanged.
- Support document-start installation, late review insertion/removal, ID renaming, and body replacement. Keep native CSS as fallback when MutationObserver is unavailable.
- Keep every other stylesheet, all existing image taming, shared controls, non-hot routes, child frames, and startup style restoration intact.
- Normal performance, FULL, VIEWPORT and TRANSITION probes retain their functionality; only version stamps change. No new diagnostic workload runs by default.

## Scope and limits

This is a source release for the existing GitHub Actions build pipeline, not a locally linked or phone-tested DEB. The local synthetic improvement is evidence for this focused change, not a guarantee of equivalent phone latency. Capture the same normal Search → product → gallery interaction after installing the passing build. Do not use the intentionally expensive `arm styles` experiment for that comparison.

The public source package contains no user's probe archive, screenshots, shopping data or URLs from the capture.
