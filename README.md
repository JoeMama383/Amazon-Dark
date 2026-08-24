# AmazonDark v7.0.49

Built on v7.0.46 (`a6a6d86`).

## Sponsored glyph: painted again, to sheet ink

v7.0.48 removed the paint on the theory that `color-scheme: dark` would make Amazon
render its own dark values for this control. It does not — the glyph went dark again. So
it is painted, but not to pure white the way v7.0.47 did it.

    brightness(0)      flatten the sprite to solid black, whatever it started as
    invert(1)          take it to #ffffff
    brightness(0.91)   land it on ~#e8e6e3

`#e8e6e3` is the ink this sheet uses everywhere else, which is what makes the glyph
uniform with the standalone APE ads rather than brighter than them. The label takes the
same value directly.

## Chevrons: the rules were scoped to the Home deck

Every existing chevron rule is scoped under `#gwm-PageContent`, `#gwm-Deck`,
`#gwm-Deck-btf` or `.gwm-dashboard-container`. A chevron rendered anywhere else matches
nothing — which is exactly why they are dark everywhere rather than only on Home.

This is the same failure as the `#gwm-PageContent` floor scope fixed in v7.0.22. The
sprite leaf `i.a-icon.a-icon-dropdown` is now owned **unscoped**, with the same filter.
The existing scoped rules are left in place as narrower fallbacks — the v7.0.42–46 work
is not touched, `a-icon-dropdown` is still at 8 sites.

## Verification

- Selector test in a real engine: the chevron sprite matches **outside** any gwm deck
  scope (reproducing what was broken), the glyph matches on a hashed class, both rules
  parse, and the filter resolves to sheet ink rather than pure white. 4/4.
- Balance 0/0/0; `scripts/lint-logos.sh`.

## If a chevron is still dark

Then that one is not the `a-icon-dropdown` sprite and needs its own leaf identified —
a one-element probe on that card family, not another blind selector.
