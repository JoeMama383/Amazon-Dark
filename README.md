# AmazonDark v7.0.66 — AmazonDark owns the card-header chevron

## The leaf, confirmed

The v7.0.65 capture ended a long guessing sequence. The chevron is:

    svg[class*=header-icon]  20x20  viewBox="0 0 24 24"
      <path d="M7.0422 22 … L15.0381 12.0004 L6.30959 3.71072 … L18 12.0004">

That path is a two-segment `>`. It appears as `_npack-asin-card_style_header-icon__…`,
`_multi-category-card_style_header-icon__…` and `_cXVhZ_header-icon_…` — the same icon
across every card family, which is why it was dark everywhere.

**Why it took so long:** every rule before v7.0.65 set `fill` on the `<svg>`. A `<path>`
carrying its own fill ignores that entirely. The sweep reported `fill=none` — the svg's
value — and I read it as "nothing is painting it" rather than "we are painting the wrong
node". It now reports `fill=rgb(232,230,227)`, so the path-level targeting works.

## This build

Colour set to `#a7a7a7`, read from the reference screenshot. Applied **unscoped**, since
the sweep proves the class spans multiple card families — scoping it to one container is
exactly what left chevrons dark in earlier builds.

**Colour properties only.** Verified programmatically that the rule sets nothing but
`fill`, `stroke`, `color` and `opacity`:

    properties set: ['color', 'fill', 'opacity', 'stroke']
    geometry/imagery properties touched: none

No `width`, `height`, `viewBox`, `transform`, `content`, `mask`, `background-image`,
`display` or `visibility`. The symbol, geometry and artwork remain Amazon's.

## If the grey is off

`#a7a7a7` is my read of a JPEG, not a sampled value. It is a single literal appearing
three times in one rule — give me the hex you want and it is a one-line change.

## Verification

Rebuilt the exact captured markup in a real engine:

- the path is owned across all three card-family class variants
- the colour resolves to `#a7a7a7`
- `viewBox`, `width`/`height` and the path `d` data are unchanged
- the rule contains no transform, content, mask or background property

8/8. Balance 0/0/0; `scripts/lint-logos.sh`.
