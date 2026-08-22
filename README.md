## v7.0.7
- Restores structural-only OLED ownership after v7.0.5 overpaint; restores light text, gray borders, bottom-nav tint, and stricter splash handoff.

# AmazonDark v7.0.7 — Stock UI / OLED Floors

No inversion and no generic recoloring. Amazon remains stock except structural interface floors are owned as OLED black across native UIKit/React, WKWebView backing surfaces, and Web DOM/composited page shells.

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
