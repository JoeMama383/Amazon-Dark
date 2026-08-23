# AmazonDark v7.0.39

Production build based directly on v7.0.38 / v7.0.29 architecture.

## Fixes

- Completes TWB for ordinary Home card IMG leaves that do not advertise
  `a-amazon-image`, `asin-image`, `product-image`, or a known image-wrapper class.
- Covers the ordinary dashboard carousel, Trending, Smart Home, Keep Shopping,
  multi-category cards, and similar Home panes using static CSS only.
- Normalizes blend on the real IMG leaf plus PICTURE/image-wrapper hosts without
  filtering the wrapper/card. This targets the Disney front-card media that
  appears during long press but disappears again after release.
- Adds an exact `.a-cardui-header` light-text owner for the one dashboard-card
  header that can hydrate dark. Sponsored/ad-feedback remains Amazon-controlled.
- Existing dedicated hero/single-creative/video/canvas/child-frame TWB remains
  intact; this rule does not replace hero coverage.

## Performance

- MutationObserver: 0
- querySelectorAll: 0
- TreeWalker: 0
- scroll listener: 0
- setInterval: 0
- requestAnimationFrame: 0
- media enumeration: 0
- recurring timer/scanner: 0

No probe code ships in this build.
