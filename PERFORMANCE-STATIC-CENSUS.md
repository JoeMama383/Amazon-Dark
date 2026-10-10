# AmazonDark architecture census — current source

**Warning:** This is a static source-token census, not a runtime benchmark. `Tweak.xm` includes diagnostic and native logic, and counters measure occurrences, not rates. Diagnostic probes are dormant unless explicitly armed.

| Source group | Files | Code bytes (raw) | MutationObserver | setInterval | requestAnimationFrame | TreeWalker | querySelectorAll | setTimeout | native dispatch_after |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| native combined (production + diagnostic hooks) | 1 | 938,820 | 0 | 0 | 0 | 0 | 1 | 0 | 1 |
| opt-in diagnostics | 11 | 248,196 | 1 | 0 | 5 | 6 | 21 | 6 | 30 |
| production / combined | 38 | 335,373 | 0 | 0 | 0 | 0 | 8 | 2 | 0 |

## Scanner and recurring-work sites

| Source file | Group | Patterns present |
|---|---|---|
| `src/ADKeepShopping7613.js` | production / combined | querySelectorAll=4 |
| `src/ADNewMenus7482.js.inc` | production / combined | querySelectorAll=2 |
| `src/ADNewMenus7622.js` | production / combined | setTimeout=2 |
| `src/ADPDPMainStream7451.js.inc` | opt-in diagnostics | TreeWalker=2, querySelectorAll=6, setTimeout=3 |
| `src/ADPDPShareGate7456.js.inc` | opt-in diagnostics | querySelectorAll=1 |
| `src/ADPerformance7596.js` | opt-in diagnostics | requestAnimationFrame=2, setTimeout=1 |
| `src/ADReviewBusiness7593.js.inc` | production / combined | querySelectorAll=2 |
| `src/ADSkeletonProbe7339.js.inc` | opt-in diagnostics | MutationObserver=1, requestAnimationFrame=3, querySelectorAll=2, setTimeout=1 |
| `src/ADUIImmediate7568.js.inc` | opt-in diagnostics | querySelectorAll=1 |
| `src/ADUniversalUIProbe7362.frame.js.inc` | opt-in diagnostics | TreeWalker=2, querySelectorAll=5, setTimeout=1 |
| `src/ADUniversalUIProbe7362.js.inc` | opt-in diagnostics | TreeWalker=2, querySelectorAll=6 |
| `src/Tweak.xm` | native combined (production + diagnostic hooks) | querySelectorAll=1 |

**Interpretation:** `querySelectorAll()` in a document-start one-shot is not equivalent to a recurring MutationObserver. Production source can include bounded DOM inspection on DOMContentLoaded/load; inspect the owner and gate before deleting. Explicit probes use TreeWalkers, RAF, and observers for their capture windows and must remain available.
