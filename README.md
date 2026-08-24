# AmazonDark v7.0.62

## The chevron was ours all along

The v7.0.61 sweep identified it in one capture:

    svg cls=_npack-asin-card_style_header-icon__2cuVV   20x20
    color=rgb(232,230,227)   filter=brightness(0.5)   fill=none

It is an inline `<svg>` whose path inherits `color: rgb(232,230,227)` — already the
correct light ink. Then **our own TWB media-dimming rule applies
`filter: brightness(0.5)`**, halving it to about `rgb(116,115,113)`. That is the dark
chevron.

Four rules were written to paint it lighter across v7.0.42–61. None could work, because
nothing was painting it dark — a filter was dimming something already correct. The same
class appears as `_multi-category-card_style_header-icon__…` and `_cXVhZ_header-icon_…`,
so it spans every card family on Home, which matches "dark everywhere".

The TWB exclusion chain has `:not([class*=icon])`, but this class is `header-icon` on the
**svg itself**, and the surrounding `:not(:where(… *))` guards only exclude *descendants*
of an ad-feedback or sponsored subtree, never the element itself. Both exclusion chains
now also carry `:not([class*=header-icon])`.

## The sponsored glyph revert, same root cause

`ad-feedback-spr` fell through the identical gap: `:not([class*=sprite])` does not match
`spr`, and `:not(:where([class*=ad-feedback] *))` covers descendants only. So the painter
tinted the glyph to the label colour, and our own TWB filter then re-dimmed it — which is
why it looked correct for a moment and then went dark, and why neither a settle train nor
a persistent style rule fixed it. Both chains now exclude `[class*=ad-feedback]`,
`[class*=sponsored]` and `[class*=spr]`.

## Not fixed: Disney card images

Not enough evidence. The point capture landed on a *working* multi-category image
(`_multi-category-card_image_round-corners__22iOW`, `filter=brightness(0.5)`, visible),
not a broken one. Press-and-hold revealing the image is iOS's link-preview sheet
rendering it independently, which tells us the image data is fine and something in the
normal paint path is hiding it — but not what.

The next capture should tap directly on one of the invisible Disney tiles.

## Verification

- Selector test: the chevron svg no longer matches the dimming selector, the sponsored
  sprite no longer matches, and a product image **still** matches so taming is preserved.
  3/3.
- Both exclusion chains extended; balance 0/0/0; `scripts/lint-logos.sh`.
