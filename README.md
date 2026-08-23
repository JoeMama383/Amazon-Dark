# AmazonDark v7.0.28

Probe-driven Home ownership correction.

- Stops using NPACK/GWM generated bundle-family prefixes as floor selectors. Those prefixes also occur on `badgeLabel`, `ad-feedback-text`, metadata and image descendants.
- Below-fold Home floors are owned only through actual shell semantics.
- The ordinary carousel immediately below the hero is isolated through `.gwm-dashboard-container`; the hero remains Amazon-owned and retains original creative colors.
- `% off` badgeLabel is not styled or repainted by AmazonDark.
- `badgeMessage` alone has a transparent background/no shadow, removing the white plate behind `Limited time deal`.
- Sponsored/ad-feedback text and info glyphs are isolated from AmazonDark-specific presentation app-wide. Amazon controls their stock color, sprite/mask/SVG, geometry and spacing.
- Generic SVG background clearing is removed so tiny stock feedback glyphs cannot be erased by media-protection CSS.
- Product-image `mix-blend-mode:normal` correction remains, but is narrowed to actual product-image semantics.
- Ports the narrow later-6.x/v185 APE structural shell rule: wrapper/placement/feedback backgrounds, borders, outlines and shadows are cleared so the OLED page floor shows through. Sponsored ink/artwork is untouched.
- No v7.0.27 probe runtime ships.
- No MutationObserver, Home runtime scanner, TreeWalker, scroll listener, interval, RAF loop or recurring timer.
