# AmazonDark v6.0.126

## v6.0.126 — deterministic MAB Share mask paint

Built directly from the last production base, v6.0.124. The v6.0.125 probe was diagnostic only and is not carried into this build.

The 6125 DOM probe showed the broken Share glyph is not a path/template mismatch. Across the sampled products Amazon uses the same exact leaf, `.puis-mab-overlay-icon-share`, with the correct Share SVG already present as a CSS mask. The only changing value is the mask ink: hidden/preloaded overlays computed a light background, while the visible broken overlay computed a dark background.

v6.0.126 therefore removes the failed v6.0.124 runtime row-marker guess and directly owns only that exact Share mask leaf in both first-paint and post-DarkReader CSS. Its `background-color` is pinned to white; the stock mask, row, hit target, menu layout, chevron, Save heart, Select checkbox, and More-like-this icon are otherwise untouched. The exact Share leaf is also added to Dark Reader's inline-style ignore list.

Because the probe proved the marker path was unnecessary, the MAB-specific marker helper and its observer work are removed. This is both more deterministic and lighter than v6.0.124.
