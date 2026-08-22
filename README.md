## v7.0.5

Static OLED theme built on the clean no-Dark-Reader architecture.

- All structural/native/WebKit/Web UI surfaces are OLED black.
- App-wide text contrast is light (`#e8e6e3`) with secondary copy `#b1aaa0`.
- Neutral borders/dividers use the established `#494D4D`.
- Proven cheap document-start rules are restored for Home/Search/Cart/PDP/Share/auth/variation shells, cXVhZ/NPACK/GWM compositing, long-copy reactive containers, and known structural gradients.
- Product/creative media and glyph artwork remain outside the broad background paint path.
- No Dark Reader, MutationObserver theme engine, inversion filter, scroll repair, interval, or RAF loop.
- SpringBoard launch cover is the direct v6.0.185-lineage implementation; app-side ready handoff now waits for a mounted, interactive Web document with the OLED stylesheet actually computed black.

# AmazonDark v7.0.0 — OLED floor baseline

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

Always-on visual behavior when Enabled is limited to OLED-black root/backing floors across native and WebKit interfaces. Component/card/text/glyph colors are otherwise left to Amazon.
