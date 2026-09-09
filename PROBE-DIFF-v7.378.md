# v7.378 focused FULL-probe diff

## Collapsed BYG plus-button artifact

The v7.377 FULL capture identifies the exact affected element as the real dense-grid
`button[name="submit.addToCart"]` for ASIN `B07MHJFRBJ` after its quantity stepper was
collapsed. Its circular theming is already correct:

- rect: `32x32`
- background: `rgb(48,51,53)` (`#303335`)
- border: `1px rgb(116,122,124)` (`#747a7c`)
- border radius: `100px`
- plus sprite: white

The residual paint is separate: `outline: 2px rgb(136,140,140) solid`. Because the focus
outline sits outside the circular border, it appears as four gray corners in the screenshot.
The same focused button retains that outline in the later FULL states.

v7.378 removes only this exact BYG ATC button's outline in base/focus/focus-visible/active
states. It keeps the circular 1px border.

## Crayola sparse faceout

The same v7.377 FULL run starts with 24 dense-grid faceouts and only 23 real ATC subtrees.
After the probe's complete finite top-to-bottom sweep it is still 24/23. The row-2/col-2
Crayola faceout still has only image + product title; its price/details tail and ATC subtree
never appear.

This disproves the v7.377 synchronous `scrollLeft +/- 1 -> restore + resize` renderer nudge
for this live renderer. Historical refresh captures are the evidence-backed recovery that
actually yields Amazon's normal real ATC subtree.

v7.378 therefore allows one document reload only for the exact one-sparse-card signature:
one base card with no price and no ATC, every other faceout healthy. `sessionStorage` is set
before reload, so a persistently sparse renderer cannot reload twice. A complete render clears
the guard for a genuinely later navigation.
