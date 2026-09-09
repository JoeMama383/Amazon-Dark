# v7.377 focused probe diff

## BYG `anonCarousel3`

| Capture | Phase | Faceouts | ATC overlays | Row 2 / col 2 |
|---|---|---:|---:|---|
| v7.374 r1 (good) | initial-full | 14 | 14 | `asin-id-B0096XWNNY` ATC present; price/details tail present |
| v7.374 r1 (good) | post-sweep-full | 14 | 14 | still complete |
| v7.376 r1 (bad) | initial-full | 8 | 7 | image + title only; ATC absent; price/details tail absent |
| v7.376 r1 (bad) | post-sweep-full | 8 | 7 | still sparse |
| v7.376 r2 (bad) | initial-full | 8 | 7 | same sparse position |
| v7.376 r2 (bad) | post-sweep-full | 8 | 7 | still sparse |

The geometry is stable: the missing card is `x=162.9, y=410.5`, row 2 / column 2 of `anonCarousel3`, matching the Crayon position in the supplied screenshots. This is not a hidden/black plus. The renderer tail never exists in the bad DOM.

### Why v7.375 recovery misses it

The production predicate was:

`img && productTitle && .a-price && !ATC`

The observed bad card has no `.a-price`, so it can never enter the recovery lane. v7.377 uses:

`img && productTitle && !price && !ATC`

with exactly one sparse faceout and every sibling carrying ATC before the one-shot renderer activation is allowed.

## BYG expanded stepper

The v7.376 initial capture records the active `a-stepper-inner-container` at `x=168.9,y=258,w=129.9,h=32` under `byg-dense-grid-atc-container` as:

- background `rgb(255,255,255)`
- border `3px rgb(255,216,20)`
- radius `16px`
- trash/add sprite `filter:none` in quantity 1 state
- remove/add sprite `filter:none` in quantity 2 state

This explains the white/yellow control in the screenshot and proves it is a separate selector family from Cart. v7.377 applies the accepted Cart palette directly to that exact dense-grid stepper path.
