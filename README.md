# AmazonDark v6.0.119

## v6.0.119 — restore v5.446 chevron-menu glyph paint

- Exact production base: v6.0.118; the successful initial-Search repair path is preserved.
- Restores the v5.446 `lists-framework-action-button` foreground and documentStart glyph-leaf rules that were lost when the branch returned to the v6.0.103 base.
- In the chevron overflow menu, Save / Select / Share are handled at their actual tiny glyph painters rather than filtering the menu row.
- The submenu More-like-this copy keeps the canonical white stacked-cards/+ image but drops the main product-card circular chrome.
- Uses the exact `.puis-mab-overlay-row` class token; no overlay `:has()` selector, DOM scan, observer, timer, scroll listener, RAF, or event listener is added.
- The normal product-card two-cards button, Heart behavior, Search first-open path, checkbox owner outside the menu, and all other v6.0.118 behavior remain unchanged.

## v6.0.103 — make the More Like This two-cards icon single-paint

- Exact source base: v6.0.101. The unsuccessful v6.0.102 swatch/deal experiment is intentionally not carried forward.
- Fixes the lower-left More Like This two-cards control painting in two visible stages (temporary white/gray child art, then the final cards glyph).
- The finished dark circular chrome + white stacked-cards/plus glyph is now owned in the earliest documentStart CSS and repeated in the post-DarkReader fixes sheet, so first paint and settled paint are identical.
- Amazon's lazy child IMG/SVG/icon painters inside only `.mlt-icon-container` are kept visually transparent; their layout and click target are not removed.
- The existing `sym413` pass now recognizes `.mlt-icon-container` as declaratively owned and skips its old 48-descendant live-art scan after one cleanup.
- No new observer, scroll listener, interval, RAF, timeout, selector traversal, native hook, or image sampler is added.
