# AmazonDark v6.0.112

## v6.0.112 — correct the product-card overflow menu symbols

- Exact code base is v6.0.104, the last-good build requested for this branch. No v6.0.105–v6.0.111 Heart experiments are included.
- Keeps the v6.0.104 main More-like-this control unchanged: its circular dark button and canonical white stacked-cards/plus glyph still paint on the first frame and remain protected from `gfix1`.
- In the chevron overflow menu only, strips that circular button chrome from `.mlt-icon-container` while retaining the canonical stacked-cards/plus background image. The menu therefore shows the bare cards/+ glyph instead of a second circular control.
- Restores light menu action glyphs by whitening only the historical `puis-mab-overlay-row-wid*` right-side widget on non-MLT rows. This covers the black Save and Select painters without touching row text or the More-like-this host.
- The same rules are present in both the earliest documentStart sheet and `ADFixesLiteral`, so the corrected menu paint is available on its first visible frame and remains authoritative after Dark Reader.
- No new JavaScript, MutationObserver, selector traversal, scroll listener, interval, RAF, timeout, dispatch queue, native hierarchy walk, or image sampler is added.
