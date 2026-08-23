# AmazonDark v7.0.24

Probe-driven Home/media/badge correction plus a narrow v6.0.185 tab-rendering port.

- Home card floors are scoped to `#gwm-Deck-btf` plus legacy `#gwm-PageContent`; bare `#gwm-Deck` is excluded so the top hero/carousel keeps its media-backed cards.
- Card ownership is hash-agnostic (`asin-container`, `mosaic-card`, `asin-data-attribute-wrapper`, `p13n-uf`, etc.).
- Structural floor rules no longer paint text leaves.
- `% off` / badge / deal / coupon / discount subtrees are excluded from structural floors. `badgeLabel` stays Amazon red with white text.
- Product IMG/image-wrapper/`asin-metadata` compositing is normalized from multiply to normal inside the owned below-fold cards. TWB brightness filters are preserved.
- Ad-card text is white with transparent text backgrounds.
- `ANXTabBarView` remains OLED black.
- The v6.0.185 bitmap-to-template/tint interception + touch/selection reassertion + thin selected-indicator ownership pattern is restored locally for the current ANX bar.
- Per current request, all bottom-nav glyphs and the thin selected indicator are white.
- No MutationObserver, global DOM scan, scroll listener, recurring timer, interval, or RAF theme loop is added.
