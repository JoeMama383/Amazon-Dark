# AmazonDark v7.372 audit

## Baseline
- Direct parent: `7.371~checkout-residual-ui-fix`
- Parent `src/Tweak.xm`: `da66033274dea49d6fc5d171a139e8372e703aa48eeec4978bd3a76f0eb04c85`

## FULL probe r1 evidence

### Bright Amazon `a` loader
The BYG probe captured:
- `li.a-carousel-card.a-carousel-card-empty`
- direct child `.a-loading-static`
- direct child `.a-loading-static-inner`
- `.a-loading-static` computed `rgb(243,243,243)` with light borders
- `.a-loading-static-inner` carries Amazon's authored background image.

That is the same loader family Cart already themes. v7.372 copies the Cart treatment:
`#303335` outer loader, `#494d4d` edge, transparent inner, and the existing
`brightness(0) invert(1) brightness(.62)` / `.72` opacity glyph treatment.

### `Ends in …` white chip
The exact `[class*=_badgeMessage_]` node computes authored red `rgb(204,12,57)` text but
`rgb(250,250,250)` background. v7.372 makes only its background transparent. The red text
is not recolored.

## Boundary
Both changes live only in the isolated checkout/BYG stylesheet. Shared WebUI programs and
the universal FULL/VIEWPORT probe architecture are unchanged.
