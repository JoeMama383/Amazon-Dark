# AmazonDark v6.0.137

## v6.0.137 — restore stock Sponsored presentation and dark backgrounds

- Removes the v6.0.135/v6.0.136 Sponsored text and glyph ownership path. AmazonDark no longer recolors, filters, resizes, replaces, duplicates, or synthesizes Sponsored labels/info glyphs. Amazon owns their stock gray typography, icon geometry, spacing, and artwork.
- Removes the v6.0.135 APE/standalone floor clearer and its Dark Reader ignore entries. This backs out the structural transparency path associated with the light-background regression.
- Removes all 6135/6136 callbacks from the existing native-ad MutationObserver; no replacement observer, timer, tree walk, scroll listener, or RAF loop is added.
- Other 6.x theming systems are intentionally unchanged.

# Previous release notes

# AmazonDark v6.0.136

## v6.0.136

Sponsored info badges now keep Amazon's stock artwork, native dimensions, baseline, and spacing. AmazonDark no longer injects, sizes, or synthesizes a replacement Sponsored SVG. The semantic Sponsored owner locates the existing native info painter and normalizes only its visible ink to white across bitmap/background-image, IMG, SVG, mask, and pseudo-element variants.

Only one existing glyph path is marked per Sponsored label. If a template has no native info glyph, AmazonDark creates none. This removes the v6.0.135 duplicate gray+white Home glyph and eliminates custom-glyph height/spacing drift. Sponsored label typography is also left at Amazon's native font metrics; only light ink/visibility is normalized. The v6.0.135 standalone/APE floor cleanup remains unchanged.

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
- Package version: `6.0.136`
- Runtime version: `v6.0.136`
- Rootless iOS 15+
