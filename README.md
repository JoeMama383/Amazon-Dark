# AmazonDark v7.0.47

Built on **v7.0.46** (`a6a6d86`).

## Correction

The previous attempt at these fixes was built on v7.0.21 — I fetched at the start of
that task and did not re-check origin before packaging, so it was 25 commits behind and
would have reverted the v7.0.42–46 chevron work. Discarded.

## Chevrons: already fixed at v7.0.46, left alone

v7.0.46 targets the actual sprite leaf — `i.a-icon.a-icon-dropdown` under the Home deck
and the `puis-mab-chevron` families. That is the correct root cause and is more precise
than the generic `[class*=chevron]` rule I was about to port from v6.0.185. Overwriting
it would have been a regression. Untouched here: `a-icon-dropdown` still has 6 sites.

## Two gaps that were real

Both had **zero occurrences** in v7.0.46, so nothing owned them.

**Sponsored info glyph.** Now uses the same `brightness(0) invert(1)` the chevron work
relies on: `brightness(0)` flattens the artwork to solid black whatever it started as,
`invert(1)` flips it to solid white. That avoids needing to know whether Amazon mounted
the sprite, the SVG or the mask variant on a given card. `position:relative; z-index:2`
covers the other failure mode — on some cards it is not mis-coloured but buried under
the card floor. The adjacent `ad-feedback-text` label is set to `#e8e6e3`.

**Scrollbar.** Never ours: v6.0.185 got it from Dark Reader's `styleSystemControls`.
Without Dark Reader, Amazon's authored near-black thumb sits on the OLED floor and
disappears. Neutral grey thumb (`#6f6f6f`, `#8a8a8a` hover) over a transparent track.

## Verification

- `a-icon-dropdown` sites unchanged at 6 — the v7.0.42–46 chevron work is intact.
- `ad-feedback-spr` 0 -> 1, `::-webkit-scrollbar-thumb` 0 -> 2.
- Balance 0/0/0; `scripts/lint-logos.sh`.
