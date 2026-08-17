# AmazonDark v6.0.102

## v6.0.102 — eliminate residual deal + swatch hydration repaint, with probe 6102

- Keeps the v6.0.100/v6.0.101 structural-shell and outer-ring fixes that already reduced the search-result flashes to a subtle repaint.
- Probe 6101 shows the remaining swatch change one layer inward: Dark Reader adds inline-background ownership to `.s-color-swatch-inner-circle-fill` after insertion and the 20x20 `.s-color-swatch-inner-circle-border` also changes color. v6.0.102 excludes those exact nodes from Dark Reader inline rewriting, preserves Amazon's real variant color, and pins only the inner ring paint.
- The 6101 probe also had a blind spot for `Limited time deal`: when a recycled product card contained both a status badge and a deal chip, its first-descendant lookup could return Amazon's Choice / Best Seller before the deal node. Probe 6102 prioritizes exact `Limited time deal` text.
- Production deal ownership now runs synchronously from the already-existing lazy-content MutationObserver. Only an added subtree whose text contains `Limited time deal` is inspected; the exact badge/deal/label host is marked, Dark Reader's inline-background marker is removed, and the settled `#a50b31` / white-text paint is pinned before the normal deferred contrast pass.
- No new MutationObserver, scroll listener, interval, RAF, dispatch-after retry, or recurring timer is added. The only new production DOM query is literal-text gated to added subtrees containing `Limited time deal`; probe-only targeting adds the other diagnostic query.
