## v7.523 — Returns left-corner rehydration

The v7.522 r2 capture identifies the remaining left-corner failure precisely: `yr_item_0` still owns Amazon's authored 292×69.3, radius-12, 1-point border, but a separate opaque 60×67.3 paint-only child fills the reserved thumbnail column at card-local approximately (1,1). That child sits above the parent border raster and covers only the top-left and bottom-left arcs after submenu/back rehydration. v7.523 clears only that exact nested paint plane during mount, layout, section priming, and React background rewrites. It does not change card width, height, radius, edge widths, carousel spacing, or the v7.522 label-centering correction.

The FULL/VIEWPORT/TRANSITION probe machinery is unchanged apart from the v7.523 identity bump. See `REVIEW-v7.523.md` and `COMMANDS.md`.

## v7.522 — Returns label centering

Centers the existing Returns text wrapper from rendered glyph bounds within its authored card. Reapplies after React layout and text commits. Keeps card geometry and existing probes.

## v7.521 — Returns corners and probe scheduling

The v7.520 r5 Person capture completed seven scroll checkpoints, reached the bottom, and restored offset zero. v7.521 cleared the near-full square inset content plane that was covering the card's authored rounded border, while retaining Amazon's original geometry.
