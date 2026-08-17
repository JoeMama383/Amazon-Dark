# AmazonDark v6.0.104

## v6.0.104 — keep the More-like-this two-cards icon stable after first paint

- Exact production base is v6.0.101; the v6.0.102 swatch/deal experiment is not included.
- Retains the v6.0.103 first-frame approach: `.mlt-icon-container` paints one canonical dark circle + white stacked-cards/plus SVG immediately, while Amazon's transient child IMG/SVG artwork remains visually hidden.
- Fixes the v6.0.103 regression where that correct first frame later became a solid white disc.
- Root cause is the existing generic `gfix1` lane: because v6.0.103 gave the small `.mlt-icon-container` itself a CSS `background-image`, the later glyph repair classified the whole 32px host as monochrome artwork and applied `filter: brightness(0) invert(1)` to the entire circle.
- v6.0.104 adds only `.mlt-icon-container` to that generic glyph lane's existing `SKIP` family. The dedicated two-cards owner remains authoritative, so the host cannot be re-filtered after hydration.
- The runtime `sym413/cards440` path still short-circuits this exact host after one cleanup, so Amazon's later placeholder/bitmap swaps cannot become visible or re-own the icon.
- No new observer, scroll listener, interval, RAF, timeout, dispatch queue, or selector traversal is added.
