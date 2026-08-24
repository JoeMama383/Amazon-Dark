# AmazonDark v7.0.63

## The v7.0.62 fix never applied

The v7.0.62 sweep, taken on v7.0.62, still reports:

    svg cls=_npack-asin-card_style_header-icon__2cuVV   filter=brightness(0.5)

My v7.0.62 edit targeted a single-line form of the selector. The two chains that
actually put `svg` in the subject list are **split across source lines**, so the replace
matched nothing and silently changed the wrong thing — it extended the `img`-only
chains instead. The verification I ran then tested my hand-written selector string, not
the one in the file, which is why it passed while the build did nothing.

Both `:is(img,svg)` chains now carry the exclusion, verified by re-reading them out of
the source rather than from a string I typed.

## The chevron, restated

It is an inline `<svg class="…header-icon…">` whose path inherits
`color: rgb(232,230,227)` — already correct. `brightness(0.5)` halves it to about
`rgb(116,115,113)`. Nothing was painting it dark; our own media-dimming filter was
dimming something already right. The class appears as `_npack-asin-card_style_…`,
`_multi-category-card_style_…` and `_cXVhZ_…`, which is why it was dark on every card
family.

`ad-feedback`, `sponsored` and `spr` are excluded on the same chains, which should also
stop the sponsored glyph being re-dimmed after the painter tints it.

## Disney card: still no evidence

This capture landed on a working `_YW1he_product-image` tile, not an invisible one. Its
container `_YW1he_container_…colored-background_…` computes `bg=rgb(247,247,247)` — a
light plate we are not darkening — but that tile renders fine, so it is not the fault.

A capture with the tap on an actually-invisible Disney tile is still what is needed.

## Verification

- Both `:is(img,svg)` chains re-read from source and confirmed to carry
  `:not([class*=header-icon])`.
- Selector test: all three chevron class variants no longer match the dimming selector;
  a product image and a hero creative still do, so taming is preserved. 5/5.
- Balance 0/0/0; `scripts/lint-logos.sh`.
