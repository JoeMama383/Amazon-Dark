# AmazonDark v6.0.203~probe — direct OLED floor + intact Dark Reader

Base: exact v6.0.195~probe source, the last source before v6.0.196 introduced the broad light-surface regression.

This build drops the v6.0.201/202 direct-theme experiment. Dark Reader remains fully attached/enabled and continues to own detailed WebKit theming. AmazonDark directly owns only the page/root canvas and WebKit backing floor as OLED black, using one tiny document-start stylesheet plus the existing constant-time WKWebView/WKScrollView/WKContentView backing hooks. No cards, text, controls, badges, gradients, or general structural surfaces are newly rethemed.

# AmazonDark v6.0.195~probe — PDP video-carousel hydration + Share rehydration

Base: v6.0.194~probe.

## v6.0.195 corrections

### PDP / product video-carousel startup and scrolling

- Narrows the existing Amazon-native island MutationObserver so the video-control repair no longer runs for every added DOM node. It wakes only when the mutation actually contains a VIDEO element or nearby play/pause/mute/volume semantics.
- Caches a successfully resolved VIDEO + play/mute control pair. Repeated `loadedmetadata` / `canplay` / `playing` lifecycle events fast-return while the same video source, parent and controls remain mounted.
- Removes redundant video-control `loadeddata`, `play` and `pause` recovery events. A delayed retry is scheduled only when the first exact repair misses.
- Video-control clicks now repair only the local video instead of rescanning every VIDEO in the document twice.
- The initial video-control reconciliation is deferred to idle / a short fallback timeout instead of running synchronously as soon as the page bootstrap settles.
- The contrast MutationObserver rejects pure VIDEO/SOURCE/TRACK/IMG/PICTURE/CANVAS hydration leaves and empty video-only shells so direct media owners do not also trigger the 360-node fallback contrast walk.
- Direct TWB removes its redundant `loadeddata` listener. VIDEO taming itself is unchanged: no per-frame/timeupdate handler is introduced.

### PDP Share glyph after dismissing Share

- Keeps v6.0.194's focus-ring cleanup.
- Restores runtime ownership for `.ssf-share-trigger`, following the old v5.446/v6.0.26 principle: inspect only the bounded Share subtree, find its actual IMG/I/SVG/background/mask painter and pin that leaf white.
- Reuses the existing symbol/product-control lifecycle; no new MutationObserver is created.
- When Amazon removes the Share sheet, the existing filtered observer immediately reasserts the Share painter and performs one bounded +80 ms convergence pass. The temporary pressed state is not replaced with a permanent circle.

## Preservation

- v6.0.193 screenshot Share preview background ownership retained.
- v6.0.191 Product images gallery ownership retained.
- Buy Again / Interests fixes retained.
- JIT, 120 Hz, Dark Reader, carousel-dot, checkbox/Heart/cards and current TWB strength behavior are not intentionally changed.

## Device test

1. Force-close/reopen Amazon.
2. Open a PDP with the video carousel near the bottom.
3. Scroll into that carousel before it has fully settled and immediately swipe through the video cards; compare initial responsiveness and frame hitching with v6.0.194.
4. Tap the main PDP Share glyph, allow the Share sheet to appear, dismiss it, and verify the glyph returns/remains white with no persistent white ring.
5. Verify Product images and the screenshot Share preview remain tamed.
