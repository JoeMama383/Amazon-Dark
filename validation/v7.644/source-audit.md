# AmazonDark architecture census — current source

**Warning:** This is a static source-token census, not a runtime benchmark. `Tweak.xm` includes diagnostic and native logic, and counters measure occurrences, not rates. Diagnostic probes are dormant unless explicitly armed.

| Source group | Files | Code bytes (raw) | MutationObserver | setInterval | requestAnimationFrame | TreeWalker | querySelectorAll | setTimeout | native dispatch_after |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| native combined (production + diagnostic hooks) | 1 | 954,667 | 0 | 0 | 0 | 0 | 1 | 0 | 1 |
| opt-in diagnostics | 13 | 278,377 | 1 | 0 | 5 | 6 | 21 | 14 | 30 |
| production / combined | 44 | 389,541 | 0 | 0 | 0 | 0 | 9 | 2 | 0 |

## Scanner and recurring-work sites

| Source file | Group | Patterns present |
|---|---|---|
| `src/ADAccountMenus7634.js` | production / combined | querySelectorAll=1, attachShadow-hook=1 |
| `src/ADKeepShopping7613.js` | production / combined | querySelectorAll=4, getComputedStyle=1, getBoundingClientRect=1 |
| `src/ADNewMenus7482.js.inc` | production / combined | querySelectorAll=2, querySelector=6 |
| `src/ADNewMenus7622.js` | production / combined | innerText=1, setTimeout=2 |
| `src/ADOrderAdsPrivacy7620.js` | production / combined | querySelector=8 |
| `src/ADPDPMainStream7451.js.inc` | opt-in diagnostics | TreeWalker=2, querySelectorAll=6, getComputedStyle=5, getBoundingClientRect=2, setTimeout=3 |
| `src/ADPDPShareGate7456.js.inc` | opt-in diagnostics | querySelectorAll=1, querySelector=3 |
| `src/ADPerformance7596.js` | opt-in diagnostics | requestAnimationFrame=2, setTimeout=5 |
| `src/ADReviewBusiness7593.js.inc` | production / combined | querySelectorAll=2, querySelector=1, getComputedStyle=1 |
| `src/ADSkeletonProbe7339.js.inc` | opt-in diagnostics | MutationObserver=1, requestAnimationFrame=3, querySelectorAll=2, querySelector=1, getComputedStyle=5, getBoundingClientRect=1, setTimeout=1 |
| `src/ADThemeWork7637.js` | opt-in diagnostics | setTimeout=4 |
| `src/ADUIImmediate7568.js.inc` | opt-in diagnostics | querySelectorAll=1, getComputedStyle=3, getBoundingClientRect=3 |
| `src/ADUIProbeScroll7446.js.inc` | production / combined | getElementsByTagName=1, getBoundingClientRect=1 |
| `src/ADUIProbeViewportSample7449.js.inc` | opt-in diagnostics | getComputedStyle=2, getBoundingClientRect=2 |
| `src/ADUniversalUIProbe7362.frame.js.inc` | opt-in diagnostics | TreeWalker=2, querySelectorAll=5, querySelector=1, getComputedStyle=7, getBoundingClientRect=2, setTimeout=1 |
| `src/ADUniversalUIProbe7362.js.inc` | opt-in diagnostics | TreeWalker=2, querySelectorAll=6, getComputedStyle=8, getBoundingClientRect=3 |
| `src/Tweak.xm` | native combined (production + diagnostic hooks) | querySelectorAll=1, querySelector=6, getElementsByTagName=6, getComputedStyle=10, getBoundingClientRect=3 |

**Interpretation:** `querySelectorAll()` in a document-start one-shot is not equivalent to a recurring MutationObserver. Production source can include bounded DOM inspection on DOMContentLoaded/load; inspect the owner and gate before deleting. Explicit probes use TreeWalkers, RAF, and observers for their capture windows and must remain available.
