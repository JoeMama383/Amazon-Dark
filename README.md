# AmazonDark v6.0.107

## v6.0.107 — restore the Heart's opaque dark disc in every search submenu

- Production base is v6.0.105; the v6.0.106 Heart lifecycle probe is diagnostic-only and is not shipped here.
- The probe exposed a CSS-specificity collision: the legacy first-paint shell guard `[class*=puis-heart-position] div` forces `background-color: transparent !important`, which outranked v6.0.105's lower-specificity `[class*=lists-framework-action-button]` dark-disc rule.
- That is why the white Heart/border could be correct while the circular backdrop became transparent over product imagery.
- v6.0.107 keeps the v6.0.105 canonical Heart SVG and hidden transient Amazon child artwork, but raises only the real Heart host selector to `[class*=puis-heart-position] [class*=lists-framework-action-button]` / `[class*=lists-framework-action-button][class*=puis-heart-icon-container]`.
- The old shell-flattening guard remains untouched for temporary wrappers; only the actual circular Heart action button wins back `#181a1b`.
- v6.0.104's two-cards first-frame/persistence logic is unchanged.
- No new observer, selector traversal, timer, scroll listener, RAF, dispatch queue, or image sampler is added.
