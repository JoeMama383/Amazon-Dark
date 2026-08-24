# AmazonDark v7.0.64 — the chevron rule from v6.0.185, ported verbatim

## What the repo already knew

v6.0.185 owned the carousel chevrons with an explicit rule:

    [class*=hp-mosaic-container] .a-icon-next-rounded,
    [class*=hp-mosaic-container] .a-icon-previous-rounded,
    [class*=hp-mosaic-container] [class*=chevron],
    [class*=hp-mosaic-container] [class*=arrow],
    [class*=_mosaic-container_style_widgetContainer] .a-icon-next-rounded,
    ...
    {filter:brightness(0) invert(1)!important;opacity:1!important;
     color:#e8e6e3!important;fill:#e8e6e3!important;stroke:#e8e6e3!important;}

**`a-icon-next-rounded` and `a-icon-previous-rounded` had zero occurrences in the 7.x
tree.** The port kept `puis-mab-chevron` and the generic `[class*=chevron]` /
`[class*=arrow]` patterns and dropped the two leaves that actually carry the glyph.
That is why the chevrons went dark on 7.x.

The rule is now ported as written, plus an unscoped pair for the card families the
sweep shows carrying their own header controls (`npack-asin-card`,
`multi-category-card`) outside the mosaic containers.

## Correcting the record on v7.0.62 / v7.0.63

`header-icon` was never the chevron. Its path is
`M7.0422 22C6.83522 21.9992 6.63313 21.9397…` — a long multi-curve icon repeated across
cards, not a two-segment `>`. I identified it from the first SVG in a truncated sweep
and asserted it twice.

Those builds were not wasted: v7.0.63 did remove `brightness(0.5)` from those SVGs
(confirmed `filter=none` in this capture), so the dimming bug was real. It just was not
the chevron bug.

## Why the sweep never found the chevron

The sweep's selector list includes bare `svg`, and the only SVGs on the page were
`header-icon` and zero-size `a-icon-checkmark-inverse`. The chevron is an `<i>` carrying
a sprite background — `a-icon-next-rounded` — which matches none of `[class*=chevron]`,
`[class*=arrow]`, `[class*=caret]` or `[class*=dropdown]`, so it fell outside every
pattern I chose.

## Verification

- `a-icon-next-rounded` and `a-icon-previous-rounded`: 0 -> 3 occurrences each.
- Selector test: chevrons inside both mosaic container families and an unscoped one are
  all matched; `header-icon` is not touched by this rule. 4/4.
- Balance 0/0/0; `scripts/lint-logos.sh`.
