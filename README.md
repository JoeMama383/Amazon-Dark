# AmazonDark v6.0.196~probe — shared PDP carousel fast lane + Share convergence

Base: v6.0.195~probe.

## v6.0.196 corrections

### Photo + video carousel gesture/input performance

The remaining lag was not video-only. PDP photo and video carousels both hydrate/recycle DOM while the user is trying to swipe. Several AmazonDark auxiliary MutationObserver lanes were still inspecting those carousel wrapper mutations even though Dark Reader and declarative TWB selectors already own the visible media.

- Adds one cheap PDP media-carousel fast-lane predicate covering the main photo carousel, Amazon `a-carousel` shells/cards, and known video-carousel/video-card families.
- The Amazon-native/ad discovery observer now ignores those PDP carousel hydration subtrees instead of running bounded descendant discovery on each added wrapper.
- The fallback contrast observer now ignores the same PDP carousel subtrees. Dark Reader still owns ordinary dark theming; direct TWB CSS/lifecycle ownership still owns the actual IMG/VIDEO/CANVAS media.
- The filtered checkbox/dot/symbol observer still wakes for an actual dot/checkbox/Share target, but it no longer performs deep descendant queries merely because a generic carousel wrapper was inserted.
- Direct known product/photo/video media now checks its declarative selector before `getBoundingClientRect()`. Known carousel media therefore does not force synchronous layout just to confirm TWB ownership during `load` / `canplay` / `playing` events.
- Native large product/photo `UIImageView` media gets an equivalent pending/settled-negative fast path: while its one-time lightness sample is pending, or once that exact image has settled as not needing TWB, repeated React/CALayer layouts return immediately. Compact Person/Alexa semantic media and the full-screen Product images owner are unaffected.
- The broad 420-media initial/BFCache fallback classification pass is moved to browser idle time. The main PDP photo/video carousel remains first-paint-owned by CSS, so this removes startup work without delaying its TWB.
- Heavy video-control shell discovery no longer runs on `loadedmetadata`; it waits for `canplay`/`playing` (or the existing deferred/click recovery), reducing work during the earliest video-card mount burst.

### PDP Share glyph after dismissing Share

- Keeps the v6.0.194 focus-ring cleanup and v6.0.195 exact Share-painter runtime owner.
- The post-dismiss Share painter now uses the historically proven bounded convergence timings (immediate + 40/180/700/1800 ms) because Amazon can replace/re-tint the icon well after the sheet has visually disappeared.
- The convergence is triggered only by Share-sheet removal; it is not a recurring timer or carousel path.

## Preservation

- v6.0.193 screenshot Share-preview background ownership retained.
- v6.0.191 full-screen Product images ownership retained.
- Buy Again / Interests fixes retained.
- JIT, 120 Hz, Dark Reader, carousel-dot, checkbox/Heart/cards and TWB strength behavior retained.

## Device test

1. Force-close/reopen Amazon.
2. Open a PDP and immediately swipe the main product-photo carousel before everything has settled. Confirm swipes register on the first gesture and frames no longer lock while new slides hydrate.
3. Scroll to the video carousel near the bottom and do the same before it settles; compare first-touch response, not only steady-state playback.
4. Repeat after both carousels are fully hydrated.
5. Open/dismiss Share and confirm the main Share glyph returns to white and stays white with no persistent white circle.
6. Verify full-screen Product images and screenshot Share-preview TWB remain correct.
