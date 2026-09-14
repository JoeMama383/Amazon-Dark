# AmazonDark v7.417 audit — Search carousel title-strip restore

## Release
- Version: `7.417~search-carousel-title-strip-restore`
- Runtime: `v7.417-search-carousel-title-strip-restore`
- Direct parent: `7.416~location-canonical-owner`

## Root cause
The current Search autocomplete carousel still inherits the broad light-text owner, which is why the text in the screenshot is already light, but its stock-white lower caption panel escapes the floor rule. Historical diffs show v7.356 intentionally narrowed the floor to the exact `.cards_carousel_widget-sug-text` class after broader v7.353/v7.355 approaches risked claiming the media lane. The current Amazon DOM no longer reliably carries that exact class on the visible caption panel.

## Correction
- Keep the exact `.cards_carousel_widget-sug-text` OLED/light owner for older/current compatible DOMs.
- Add only structural non-media fallbacks inside `.cards_carousel_widget-sug-column`:
  - sibling following a direct media node;
  - sibling following a direct child that contains media;
  - final direct child when it contains no media.
- Every fallback rejects `img`, `picture`, `source`, and `cards_carousel_widget-sug-im*` descendants.
- Caption floor = OLED black; neutral text = light; neutral border = `#494d4d`.
- Existing product-image transparency/visibility and TWB brightness path remain untouched.
- The old broad `cards_carousel_widget-sug-*` descendant floor owner remains absent.

## Runtime cost
No new native hooks, MutationObserver, timer, RAF, polling loop, Web scroll listener, recurring DOM/native scan, or WKUserScript family. This is a static document-start CSS selector correction in the existing `/autocomplete` payload.
