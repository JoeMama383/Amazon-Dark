# AmazonDark v7.0.42

Production build based on the corrected v7.0.40 source. The v7.0.41 hero probe is removed; its findings are converted to static CSS only.

## Fixes

### Universal hero TWB for CSS-backed art
The v7.0.41 probe showed the missing hero class directly: some NPACK heroes expose the visible artwork on the `theming-card-background` leaf itself, with a `background-image`, but no `single-creative-card` / `single-video-card` ancestor. The previous selector therefore skipped those cards.

v7.0.42 shades the actual `theming-card-background` / `vjs-poster` leaf directly with an inset background shade. This is background-only paint: it does not apply a brightness filter to the hero wrapper, text, headers, buttons, or controls. IMG/VIDEO media keeps the existing leaf-local TWB filter.

### College / MAB chevron
Historical v5.440/v5.449 probes prove the visible arrow is the background-image sprite on `I.a-icon.a-icon-dropdown` below `.puis-mab-chevron`. That leaf is not reliably inside the newer seasonal mosaic wrapper.

v7.0.42 restores the exact sprite-leaf treatment directly:
`filter: brightness(0) invert(1)`.

### Isolated dashboard title
The current probe also showed the APE-backed "You might like" card uses `windowPaneHeaderContainer` rather than `wpTitle`. v7.0.42 owns that title leaf too while leaving the separate Sponsored row/glyph Amazon-controlled.

## Performance
All three fixes are documentStart CSS only:
- MutationObserver: 0
- querySelectorAll: 0
- TreeWalker: 0
- scroll listener: 0
- setInterval: 0
- requestAnimationFrame: 0
- recurring scanner/timer: 0
- probe/debug runtime: 0
