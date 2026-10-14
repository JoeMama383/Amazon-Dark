# AmazonDark v7.640 — render scope and lifecycle recovery

Base: v7.639-search-pdp-render-scope. This changes production rendering, not probe instrumentation.

## Evidence

The supplied normal v7.638 capture recorded input-to-next-animation-frame delays up to 4,068 ms, input arrival delays up to 2,111 ms, event-loop lag up to 3,390 ms and DOM interactive up to 19,285 ms. Native hook measurements were small; the child-frame repair round trip was not invoked in that capture. The separate styles capture intentionally forces expensive recalculation and is not a measure of ordinary input latency. These facts implicate remaining web rendering work but do not identify one proven sole cause.

## Changes from v7.639

- `ADRenderScope7640.js` filters owned stylesheet source before assignment on main-frame Search and product routes. It excludes only complete rules whose entire top-level selector list starts with an explicitly off-route Home, Interests, Search or product owner. It retains mixed shared selectors, at-rules and malformed-input fallback. Home, other routes and child frames receive unchanged CSS.
- On those same hot routes, skip the unused adopted Interests stylesheet. Interests itself keeps the original sheet.
- The core program retains owned style references and restores disconnected sheets at DOMContentLoaded, load and pageshow. References are bounded by style ID; a newer installed sheet wins over an old detached reference. This covers head replacement before load without waiting on ads. It is a recovery mechanism, not proof of the reported cold-boot cause.
- No MutationObserver, recurring scan, browser prototype hook, DOM geometry rewrite or changes to authored color/image-taming declarations. Existing v7.639 route exclusions remain.
- Preserve FULL, VIEWPORT, TRANSITION and normal performance capture behavior; update release stamps only. Do not use intentionally disruptive `arm styles` for normal latency verification.
- Repair an inherited Foundation syntax-test stub to declare NSRange and NSString methods already used by v7.639. Add executable scope/lifecycle regression cases and generated-helper consistency checks.

## Remaining verification

All 303 repository regression scripts passed. Synthetic WebKit checks preserve sampled tile paint/geometry and full Home/Interests sheet contents; their timing is not device latency. ARM64/iOS SDK syntax checks passed, with existing probe retain-cycle warnings. GitHub Actions must still link/package the installable DEB. No on-device install or performance improvement is claimed. Check first cold launch, Search entry taps and product gallery swipes with a normal performance capture after installation.
