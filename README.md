# AmazonDark v6.0.115

## Overflow-menu symbol repair from the v6.0.104 last-good base

- Exact code base: **v6.0.104**. Builds v6.0.105-v6.0.114 are not stacked into this source tree.
- Fixes the missing/dark **Select** glyph with a deterministic 16 px white checkbox/checkmark painter.
- Locks the stock **Share** background-image white on the exact Share-row leaf and prevents the generic glyph lane from flipping it back dark.
- Keeps **Save** white.
- Keeps the overflow-menu **More like this** painter as cards + plus only; the normal product-card button retains its circular chrome.
- Menu insertion is handled inside the already-existing filtered MutationObserver. Menu mutations are excluded from the expensive Compare-checkbox / symbol reconciliation queues, so opening the menu does not trigger a whole-page checkbox pass.
- No new observer, scroll listener, interval, RAF loop, timer, dispatch queue, global selector scan, or native hierarchy walk is added.
