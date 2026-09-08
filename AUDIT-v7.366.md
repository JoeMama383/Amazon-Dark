# AmazonDark v7.366 audit — Cart empty-caption fix

## Base
- Direct source parent: v7.365~probe-backed-cart-sameday-sustainability.
- Parent `src/Tweak.xm` SHA-256: `40829c39e2a65e5296f4d165d462b0b5aca4fdb97eb3edddd748569b07be978f`.

## Probe-backed diagnosis
The supplied v7.365 universal FULL probe captured the empty-Cart state. Its hit-test stack at the top Cart content resolves to `p.a-spacing-base.a-size-medium <- div.a-row.sc-list-caption <- form#activeCartViewForm <- div#sc-active-cart`. The full computed-paint inventory shows that visible `p` at 430x22 remains `rgb(15,17,17)` for both `color` and `-webkit-text-fill-color`. By contrast, `.sc-cart-header` is already light in v7.365 but has zero height in this state, so the earlier selector was not the visible owner.

## Change
Adds only:
`#sc-page-container #sc-active-cart form#activeCartViewForm>.sc-list-caption>p.a-spacing-base.a-size-medium`
with `color:#e8e6e3!important` and `-webkit-text-fill-color:#e8e6e3!important`.

No product link, dynamic semantic color, image, glyph, floor, border, geometry, or unrelated Cart text selector changes.

## Probe architecture
The two universal categories remain unchanged: screenshot FULL finite Web/native sweep and armed VIEWPORT current-screen capture. Operational names advance to v7.366.

## Performance
No MutationObserver, interval, RAF loop, web scroll listener, recurring scanner, or additional runtime traversal is introduced. The visual fix is one declarative exact CSS selector.
