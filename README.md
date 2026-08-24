# AmazonDark v7.0.57

Built on v7.0.56 (`2b45ac3`).

## Sponsored glyph reverting after ~1 second

The v7.0.50 painter is correct in approach: it reads the label's computed colour and
converts the sprite into a mask tinted with that exact value, so the glyph matches the
Sponsored text rather than being forced to some colour I picked. Nothing about that
needed changing.

It reverted because of **when** it ran, not what it did. Its passes were
`DOMContentLoaded`, `pageshow`, and capture-phase `load`. Amazon's Home hydrates its ad
cards *after* `DOMContentLoaded`, and those cards fire no `load` event — so the
re-render replaced the element the painter had already tinted, and nothing ran again.
Correct for about a second, then Amazon's dark sprite returns.

A short bounded settle train now covers the hydration window: passes at 0, 120, 360,
780, 1480 and 2680ms, then it stops permanently. Each pass is a no-op once the glyphs
already carry the mask.

**No observer is reintroduced.** Six bounded passes that terminate 2.7s after load are
not the same mechanism as a subtree observer firing on every mutation for the life of
the page — that distinction is the whole reason the input latency went away. Confirmed
below that the train terminates.

## Chevrons: not addressed, and why

The v7.0.56 probe captured point `320.3,910.3`, which landed on a product image. The
entire hit chain is `img.a-amazon-image._npack-asin-card_style_asin-image` ->
`asin-image-container` -> `asin-image-link` -> asin card -> `gwm-Deck-btf`, and
`TOP_OUTERHTML` is an `<img>` of a digital calendar. There is no `a-icon`, no `chevron`,
no `dropdown` anywhere in it.

So that capture contains no evidence about chevrons. The existing `a-icon-dropdown`
ownership (8 sites) is left exactly as it is. A capture with the touch point on a
chevron itself would identify the leaf in one pass; guessing again would be the third
wrong chevron rule in a row.

## Verification

- Settle train simulated: runs exactly 6 times, terminates with no pending timers, first
  pass immediate, last at 2680ms. 4/4.
- MutationObserver count still 0.
- `a-icon-dropdown` unchanged at 8 sites.
- Balance 0/0/0; `scripts/lint-logos.sh`.
