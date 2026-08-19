# AmazonDark v6.0.135

Dark-mode and UI consistency tweak for the Amazon iOS app.

## v6.0.135

This release replaces the failed v6.0.134 Sponsored normalization with one rendered owner rather than recoloring each Amazon template independently.

### Sponsored labels and info glyphs
- Finds visible `Sponsored` / `Sponsored Ad` labels semantically, including classless and lazy/recycled templates.
- Normalizes the actual label host to one presentation: solid white, Amazon Ember/Arial fallback, 13 px, 16 px line height, weight 400.
- Replaces detected native info painters with one fixed 12x12 white-disc/dark-i SVG and suppresses their original sprite/SVG/pseudo paint.
- Uses the same canonical fallback glyph when a Sponsored template has no usable native glyph painter.
- Locks width, height, transform, mask, filter, fill/text and child/pseudo paint so template-specific glyph size/color/i artwork cannot leak through.
- Reuses the existing native-ad child-list observer for lazy content; no new MutationObserver, scroll listener, interval, RAF loop or recurring timer is added.

### Standalone Sponsored ad floor
- Keeps APE wrapper/placement/feedback chrome transparent so it exposes the live page floor.
- In short/wide standalone Sponsored child frames, clears only large structural background/border/shadow painters.
- Product media, video, canvas, SVG and real CSS background-image artwork are excluded from structural clearing.
- Retains full-frame TWB rejection for product/standalone frames and Sponsored hero frames so the entire ad cannot be mistaken for one tameable image.

### Production cleanup
- Removes the v6.0.131 standalone-ad DOM/file-export probe and its resign-active exporter from the production build.
- Keeps the existing performance architecture: no added recurring scheduler or page-scroll work.

## Package
- Package version: `6.0.135`
- Runtime version: `v6.0.135`
- Rootless iOS 15+
