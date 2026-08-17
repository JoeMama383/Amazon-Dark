# AmazonDark v6.0.103

## v6.0.103 — make the More Like This two-cards icon single-paint

- Exact source base: v6.0.101. The unsuccessful v6.0.102 swatch/deal experiment is intentionally not carried forward.
- Fixes the lower-left More Like This two-cards control painting in two visible stages (temporary white/gray child art, then the final cards glyph).
- The finished dark circular chrome + white stacked-cards/plus glyph is now owned in the earliest documentStart CSS and repeated in the post-DarkReader fixes sheet, so first paint and settled paint are identical.
- Amazon's lazy child IMG/SVG/icon painters inside only `.mlt-icon-container` are kept visually transparent; their layout and click target are not removed.
- The existing `sym413` pass now recognizes `.mlt-icon-container` as declaratively owned and skips its old 48-descendant live-art scan after one cleanup.
- No new observer, scroll listener, interval, RAF, timeout, selector traversal, native hook, or image sampler is added.
