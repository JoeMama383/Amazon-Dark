# AmazonDark v7.0.61 — sweep actually reports

## Why v7.0.60 printed nothing

The sweep found 6 candidates and reported 0 rows. Every one was discarded by a
`if(r.width<1||r.height<1)continue` guard I added to skip unlaid-out nodes — so all six
are **zero-sized**.

That is the opposite of noise. A zero-sized box carrying a `::before` or `::after` is
exactly what a pseudo-element chevron looks like, and my guard was throwing away the
only candidates that matched. Guard removed; zero-sized elements are now reported, with
rect printed to one decimal so their size is visible at a glance.

## Selector widened

Six candidates on a Home page full of carousels means the real chevron matches none of
the earlier patterns. Added:

    span.a-icon, .a-icon
    [class*=carousel] button
    [aria-label*=Next], [aria-label*=Previous]  (and lowercase)
    [class*=header-link] svg, [class*=cardui-header] svg, [class*=cardui-header] i
    svg, use
    [class*=see-more], [class*=seeMore], [class*=view-all]

Cap raised 40 -> 60.

## What each row gives

Tag, classes, rect, `color`, `bg`, `background-image`, `mask`, `filter`, `fill`,
`stroke`, `opacity`, full `::before` and `::after` (content, background, background-image,
filter), and 220 characters of `outerHTML`.

If the chevron is a pseudo-element, its `BEFORE{ct=…}` or `AFTER{ct=…}` will be
non-`none` and carry the glyph or a background image. If it is an inline SVG, the `svg`
and `use` rows will show it. Either way one capture names it.

## Standing note

The unscoped rule from v7.0.49 is confirmed present in the emitted stylesheet, so it
ships and the chevrons are still dark. Whatever the chevron is, it is not
`i.a-icon-dropdown`, `[class*=chevron]` or `[class*=arrow]`.

## Verification

- Size guard removed (0 occurrences); widened selector present; cap 60.
- Balance 0/0/0; `scripts/lint-logos.sh`.
