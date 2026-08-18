# AmazonDark v6.0.114

## v6.0.114 — exact-token overflow glyphs + restore chevron responsiveness

- Rebuilt directly from the v6.0.104 last-good production base; v6.0.105-v6.0.113 are not stacked into this tree.
- Keeps the v6.0.104 Heart and normal More-like-this two-cards behavior unchanged.
- Replaces every v6.0.113 `[class*=puis-mab-overlay-row] ...` rule with exact class-token selectors from the historical v5.44x probe family.
- Save is whitened only on `.puis-mab-overlay-heart`.
- Select is whitened only on its small `i.a-icon.a-icon-checkbox`, while explicitly removing the unrelated 32px compare-checkbox box-shadow/radius inside the overflow menu.
- More-like-this keeps the v6.0.104 canonical cards/plus glyph but loses the circular button chrome only inside `.puis-mab-overlay-row`.
- Share is returned completely to the v6.0.104 stock path; no generic `.aok-inline-block` filter is applied.
- No overlay-wide SVG rule, `:has()` overlay selector, JavaScript repair, new observer, scan, timer, RAF, scroll listener, or native hierarchy walk is added.
