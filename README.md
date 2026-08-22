# v6.0.207 experimental — direct v185 nav + image preservation

- Direct-ports the v185 bottom-nav state/tint behavior and isolates the bar from the global inversion.
- Preserves every ordinary Web IMG/VIDEO/CANVAS from inversion declaratively.
- Preserves native raster UIImageView content from inversion while keeping template/chrome glyphs in the inverted UI.
- Generalizes TWB to all large non-glyph photo/media leaves without section-specific rules.
- Keeps the v206 minimal inversion architecture, SpringBoard cover, current preferences, search/top chrome, JIT and 120 Hz.

# AmazonDark v6.0.206 experimental

Minimal inversion experiment based on the v6.0.185 baseline.

Retained:
- SpringBoard custom launch picture/cover and broker component
- Existing Settings preferences (Enabled, Tame Light Backgrounds + Strength, Force 120 Hz, Enable JIT)
- Current bottom navigation behavior
- Current top/search-bar dark chrome and neutral search border
- Streamlined TWB

Experiment architecture:
- One compositor `colorInvert` filter on Amazon windows.
- Native product raster images receive the same local invert filter so product pixels remain original.
- Web product media is counter-inverted with a tiny document-start script.
- TWB applies uniformly to qualifying product media; glyph/icon families are excluded.
- No Dark Reader, native color engine, broad contrast repair, card-specific theming, probes, DOM MutationObserver, scroll listener, interval, or RAF loop.
