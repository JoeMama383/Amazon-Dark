# AmazonDark v7.374 audit

## Baseline
- Direct parent: `7.373~checkout-delivery-press-state`
- Parent Tweak SHA-256: `bd4d29a9e14bc5b1977890d545781e707ddbb7e731f848a3b8932f9c3f41534d`

## FULL r1 — recommendation grid

### Dark text
The black visible text is the exact current-price family:
`span.a-price._bW9ia_mobileDenseGridPriceToPay_*` and its
`a-price-whole` / `a-price-decimal` / `a-price-symbol` / `a-price-fraction`
descendants, all computing `rgb(15,17,17)`.

v7.374 explicitly makes this neutral price-to-pay family light while leaving authored
red deal/savings/countdown families untouched.

### Crayon card / missing plus
The center lower card has a full `_mobileDenseGridImage_` inside
`_imageAndAtcContainer_`, but the captured subtree contains no `submit.addToCart`,
no `_denseGridAxSpotAtcButton_`, and no ATC descendant at that card geometry.
The neighboring cards do contain 32x32 ATC controls. Therefore the missing plus is
Amazon-authored absence, not AmazonDark hiding it; no fake plus is injected.

## FULL r2 — checkout header first paint
Initial native snapshot:
- `_UIBarBackground`: OLED black.
- direct 430x103 image-bearing `UIImageView`: `hidden=0`.

Final snapshot after the finite FULL sweep:
- same image view: `hidden=1`.

This exactly matches the observed behavior that the yellow header turns OLED after a
scroll/layout event. v7.374 invokes the existing exact `Place Your Order` nav owner from
`UINavigationBar.didMoveToWindow` and `UINavigationBar.layoutSubviews`, before the first
composited layout completes.

## Boundary
No MutationObserver, interval, RAF loop, Web scroll listener, recurring hierarchy scan,
or renderer polling is introduced. Universal FULL/VIEWPORT probe architecture is unchanged.
