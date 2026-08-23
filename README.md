# AmazonDark v7.0.21

Probe-driven production fix.

## Bottom navigation
The v7.0.20 snapshot identified the actual visible white fill as `ANXTabBarView` (430x82).
v7.0.21 owns only that class's background as OLED black through setBackgroundColor,
didMoveToWindow, and layoutSubviews. It does not change tab icons, rendering mode,
selected/unselected tints, labels, or symbology.

## Home below-carousel floors
The probe showed the Home document root is already black. The remaining light planes are
hydrated card shells under `#gwm-Deck` / `#gwm-Deck-btf`, including:
- `.a-cardui`
- `_cXVhZ_asin-container_*`
- `_cXVhZ_mosaic-card_*`
- `_hp-mosaic-container_style_container_*`

The existing Home CSS is expanded from the stale `#gwm-PageContent` scope to the actual
current Home deck roots and these known shells are OLED black.

Probe-captured cXVhZ product images use `mix-blend-mode:multiply`; v7.0.21 normalizes
only those product-image leaves to `normal` so their artwork is preserved against the
new black shell.

The temporary v7.0.20 probe and background observer are removed.
