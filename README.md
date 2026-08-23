# AmazonDark v7.0.40

Production build based directly on v7.0.39.

## Fixes

### Seasonal mosaic labels + chevrons
v7.0.39 accidentally retained only the seasonal heading/caption foreground rule.
The earlier cheap v185/v7.0.16 port covered structural seasonal label hosts as
well as next/prev/chevron/arrow ink.

v7.0.40 restores that coverage with documentStart CSS only:
- seasonal structural label hosts use light text / text-fill;
- next / prev / chevron / arrow ink uses light color/fill/stroke;
- seasonal TWB still tames product/art IMG/SVG media;
- SVG/IMG navigation controls are excluded from TWB so the white chevron is not
  darkened by the media filter.

### One dark dashboard carousel title
Historical Home probes identify `wpTitle` as the exact leaf used for the small
"For you" / "You might like" / "Keep shopping for" dashboard titles.
v7.0.40 gives only that title leaf authoritative light ink.

The Sponsored row below it is not selected and remains Amazon-controlled.

## Performance

These fixes are static CSS only:
- MutationObserver: 0
- querySelectorAll: 0
- TreeWalker: 0
- scroll listener: 0
- setInterval: 0
- requestAnimationFrame: 0
- recurring scanner/timer: 0

No probe code is included.
