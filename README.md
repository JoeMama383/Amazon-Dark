# AmazonDark v6.0.113

## v6.0.113 — stabilize the product-card overflow menu without blocking first touch

- Rebuilt directly from the v6.0.104 last-good production base; none of the later Heart experiments are included.
- Keeps the v6.0.104 More-like-this two-cards first-frame owner unchanged on the normal circular button.
- Inside the product-card overflow menu only, removes that circular chrome while retaining the canonical white stacked-cards/plus glyph.
- Replaces v6.0.112's filtered `puis-mab-overlay-row-wid` wrapper and dynamic `:has()` exclusion with direct leaf-only selectors derived from the v5.446 probe family.
- Save (`puis-mab-overlay-heart`), Select (`i.a-icon-checkbox`), and the Share 16px `aok-inline-block` leaf are whitened directly; SVG leaves are forced to white fill/stroke.
- No whole menu-row/filter compositing surface is created, so opening the menu should no longer flash a white disc or delay touch handling.
- No new observer, selector traversal, scroll listener, interval, RAF, timeout, dispatch queue, or native hierarchy walk is added.
