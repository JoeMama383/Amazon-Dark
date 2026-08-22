# AmazonDark v7.0.3

This branch is a clean reset built from the v6.0.185 source baseline.

Retained:
- v6.0.185 Settings bundle/preferences and preference domain.
- Tame Light Backgrounds preference, reimplemented as a compact event-driven media owner with glyph/icon exclusions.
- Force 120 Hz preference.
- Dopamine per-app JIT preference and SpringBoard broker.
- SpringBoard launch cover/transition/custom splash artwork.
- Sileo/package identity, icons, PreferenceLoader wiring and metadata.

Removed:
- Dark Reader and all Dark Reader resources/runtime injection.
- Native dark-theme weblab forcing.
- Home/Search/PDP/Person/Cart special-case theming, symbol painters, borders, repair passes and probes.

Always-on visual behavior when Enabled is one app-wide compositor inversion. Product-photo media is counter-inverted once to preserve stock photographic colors; all other UI pixels remain in the global inversion lane.

## v7.0.3

- Repackage of the exact v7.0.1 architecture with version metadata only.
- No v7.0.2 Home product-photo classifier changes are included.

## v7.0.1

Clean whole-app inversion baseline. A single UIWindow compositor `colorInvert` filter now owns the app-wide visual transform. Product-photo media is the only default exception and is counter-inverted locally so photos retain stock colors. This replaces the v7.0.0 OLED-floor-only owner and does not restore Dark Reader, native recolor engines, navigation painters, DOM MutationObservers, scroll recovery, or recurring theme passes. Tame Light Backgrounds, Force 120 Hz, JIT, settings, and the SpringBoard launch transition remain.
