# AmazonDark v7.149~stock-video-controls-coupon-green-probe — stock Search video controls + coupon green

Direct base: v7.148~search-mute-coupon-fix-probe.

- Removes v7.148 custom mute SVG artwork entirely.
- Adds an explicit stock-island boundary for the Search sponsored-video WebKit play/pause and mute pseudo-controls by reverting the exact visual properties AmazonDark can spill into (appearance/background/color/filter/border/mask/blend), so AmazonDark does not own their glyph or shell paint while control geometry remains stock.
- Keeps the v7.145 accelerated-video repair: `VIDEO.sbv-video-player-ecx` remains unfiltered and TWB remains on the separate `.sbv-video-overlay` background.
- Uses the v7.148 device probe to target the exact coupon painters: `.s-coupon-tile` (the surviving pink 163.4x28 owner) and `.s-coupon-tile-price-content` (the separate right price owner). Both now use muted sage `#405a4a` with white copy; checkbox artwork is preserved.
- Retains the full manual screenshot/SIGUSR2 diagnostics, including WebKit media-control pseudo-style capture and coupon family capture.
- No MutationObserver, interval, RAF, scroll listener, or recurring scan is added by these visual fixes.
