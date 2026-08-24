# AmazonDark v7.0.60 — chevron sweep

## Why the tap probe kept failing

v7.0.59's scroll compensation worked: the capture shows `NATIVE_TOUCH screen=243.3,915.3`
and `point=243.3,915.0` in agreement, where earlier captures diverged. The coordinate is
correct.

But (243, 915) sits inside a product image's rect (227, 813, 180x182), and all three
attempts landed at y between 907 and 915 — the very bottom of a 932pt screen. Chevrons
sit in card headers. The tap is simply not hitting them, and no amount of coordinate
fixing changes that.

## The sweep

The probe no longer depends on aim. On any tap it now enumerates every chevron-ish
element in the document:

    i.a-icon, [class*=chevron], [class*=arrow], [class*=caret],
    [class*=icon-next], [class*=icon-prev], [class*=dropdown]

and reports, for each one that is actually laid out: tag, classes, rect, `color`, `bg`,
`background-image`, `mask`, `filter`, `fill`, `stroke`, `opacity`, both pseudo-elements,
and the first 220 characters of `outerHTML`. Capped at 40.

Tap anywhere on Home. The `=== CHEVRON SWEEP ===` section is appended after the existing
point capture.

## What this will settle

The unscoped rule added in v7.0.49 is confirmed present in the emitted stylesheet:

    i.a-icon.a-icon-dropdown,.a-icon.a-icon-dropdown,i[class*=chevron],
    i[class*=arrow],[class*=chevron-glyph]…{filter:brightness(0) invert(1) brightness(0.91)!important…}

So the rule ships and the chevrons are still dark. That means the chevron is not any of
those elements — it is a different tag, a pseudo-element, or an inline SVG. The sweep
reports all three cases, including `::before` and `::after` content and background
images, so one capture identifies it.

## Verification

- Sweep present in source; balance 0/0/0; `scripts/lint-logos.sh`.
