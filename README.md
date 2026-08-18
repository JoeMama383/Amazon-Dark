# AmazonDark v6.0.128

## v6.0.128 — Home standalone-ad TWB scope correction

Built directly from the v6.0.127 production source. The v6.0.126 MAB Share fix and the v6.0.127 Sponsored-label correction are retained.

The Home standalone-ad regression was a scope problem in White Background Taming, not a missing Sponsored color rule. The current 6.x TWB simplification had broadened ownership beyond the v5.446 donor: ad-placement/background wrappers could receive the same tame layer as real creative media, and the standalone/product-ad media path allowed a carousel-family match to bypass the existing full-frame skip. That can make the whole ad rectangle — including the Sponsored feedback area — look dimmed even when the label itself is already white.

v6.0.128 restores the donor separation between ad chrome and photo content:

- Restores v5.446's transparent `hybrid-widget-sponsored` / `adFeedbackMainComponent` structural backgrounds in both document-start and Dark Reader override CSS.
- Restores the bounded v5.446 `_adBgPlacement365` rule so APE/ad-feedback/ad-slot background wrappers are never White Background Tamed.
- Removes placement/sponsored wrapper families from the static canvas/background-image TWB owner; actual creative-card canvas/background media remain covered.
- Prioritizes `productad` / `standalone` full-frame media rejection before generic carousel-family eligibility, so a whole-ad image/canvas cannot be tamed as one giant photo layer.
- Keeps smaller inner IMG/VIDEO/CANVAS creative media eligible for normal TWB, preserving the intended photo-only behavior.
- Changes the exact `ad-feedback-spr` treatment from `brightness(0) invert(1)` to `invert(1)` so a black-circle/white-`i` sprite becomes a white-circle/dark-`i` sprite instead of being collapsed to one flat color.
- Adds no MutationObserver, timer, scroll listener, RAF, `querySelectorAll`, or `dispatch_after` call site.

Performance counters remain unchanged from v6.0.127 for the six tracked hot-path metrics: 3 actual MutationObservers, 33 `querySelectorAll(` call sites, 0 scroll listeners, 0 `setInterval(`, 0 `requestAnimationFrame(`, and 6 `dispatch_after(`. The donor ad-background guard remains a bounded four-parent ancestry check; the iframe test uses a tag lookup rather than adding another selector query. No page-wide scan is introduced.
